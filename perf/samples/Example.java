package example;

import java.time.Duration;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.*;
import java.util.function.Function;
import java.util.stream.Collectors;

public class Example {

    // --- Sealed interface hierarchy ---

    sealed interface Result<T> permits Result.Ok, Result.Err {
        record Ok<T>(T value) implements Result<T> {}
        record Err<T>(String message, Throwable cause) implements Result<T> {}

        default <U> Result<U> map(Function<T, U> f) {
            return switch (this) {
                case Ok<T>(var v) -> new Ok<>(f.apply(v));
                case Err<T>(var msg, var cause) -> new Err<>(msg, cause);
            };
        }

        default <U> Result<U> flatMap(Function<T, Result<U>> f) {
            return switch (this) {
                case Ok<T>(var v) -> f.apply(v);
                case Err<T>(var msg, var cause) -> new Err<>(msg, cause);
            };
        }

        default T orElse(T fallback) {
            return switch (this) {
                case Ok<T>(var v) -> v;
                case Err<T> _ -> fallback;
            };
        }
    }

    // --- Generic bounded retry executor ---

    record RetryConfig(int maxAttempts, Duration initialDelay, double backoffMultiplier) {
        RetryConfig {
            if (maxAttempts < 1) throw new IllegalArgumentException("maxAttempts must be >= 1");
            if (backoffMultiplier < 1.0) throw new IllegalArgumentException("backoffMultiplier must be >= 1.0");
        }

        static RetryConfig defaults() {
            return new RetryConfig(3, Duration.ofMillis(500), 2.0);
        }
    }

    static <T> Result<T> withRetry(RetryConfig config, Callable<T> task) {
        Duration delay = config.initialDelay();
        Throwable lastError = null;

        for (int attempt = 1; attempt <= config.maxAttempts(); attempt++) {
            try {
                return new Result.Ok<>(task.call());
            } catch (Exception e) {
                lastError = e;
                if (attempt < config.maxAttempts()) {
                    try {
                        Thread.sleep(delay.toMillis());
                    } catch (InterruptedException ie) {
                        Thread.currentThread().interrupt();
                        return new Result.Err<>("Interrupted during retry", ie);
                    }
                    delay = Duration.ofMillis((long) (delay.toMillis() * config.backoffMultiplier()));
                }
            }
        }
        return new Result.Err<>("Exhausted %d attempts".formatted(config.maxAttempts()), lastError);
    }

    // --- Virtual thread task pool with structured concurrency ---

    record TaskResult<T>(String taskName, Result<T> result, Duration elapsed) {}

    static <T> List<TaskResult<T>> runAll(Map<String, Callable<T>> tasks) throws InterruptedException {
        List<TaskResult<T>> results = new CopyOnWriteArrayList<>();

        try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
            var latch = new CountDownLatch(tasks.size());

            tasks.forEach((name, task) -> executor.submit(() -> {
                var start = Instant.now();
                try {
                    var result = withRetry(RetryConfig.defaults(), task);
                    results.add(new TaskResult<>(name, result, Duration.between(start, Instant.now())));
                } finally {
                    latch.countDown();
                }
            }));

            latch.await();
        }

        return results;
    }

    // --- Text analysis pipeline using streams ---

    record TextStats(
        int wordCount,
        int uniqueWords,
        Map<String, Long> topWords,
        double avgWordLength,
        String longestWord
    ) {}

    static TextStats analyze(String text, int topN) {
        var words = Arrays.stream(text.toLowerCase().split("\\W+"))
                .filter(w -> !w.isBlank())
                .toList();

        var frequencies = words.stream()
                .collect(Collectors.groupingBy(Function.identity(), Collectors.counting()));

        var topWords = frequencies.entrySet().stream()
                .sorted(Map.Entry.<String, Long>comparingByValue().reversed())
                .limit(topN)
                .collect(Collectors.toMap(
                        Map.Entry::getKey, Map.Entry::getValue,
                        (a, _) -> a, LinkedHashMap::new));

        return new TextStats(
                words.size(),
                frequencies.size(),
                topWords,
                words.stream().mapToInt(String::length).average().orElse(0),
                words.stream().max(Comparator.comparingInt(String::length)).orElse("")
        );
    }

    // --- Pattern matching with guards ---

    sealed interface Shape permits Circle, Rectangle, Triangle {}
    record Circle(double radius) implements Shape {}
    record Rectangle(double width, double height) implements Shape {}
    record Triangle(double a, double b, double c) implements Shape {}

    static String describeShape(Shape shape) {
        return switch (shape) {
            case Circle(var r) when r > 100 -> "Large circle (r=%.1f)".formatted(r);
            case Circle(var r) -> "Circle (r=%.1f, area=%.2f)".formatted(r, Math.PI * r * r);
            case Rectangle(var w, var h) when w == h -> "Square (side=%.1f)".formatted(w);
            case Rectangle(var w, var h) -> "Rectangle (%,.1fx%.1f)".formatted(w, h);
            case Triangle(var a, var b, var c) when a == b && b == c -> "Equilateral triangle (side=%.1f)".formatted(a);
            case Triangle(var a, var b, var c) -> "Triangle (%.1f, %.1f, %.1f)".formatted(a, b, c);
        };
    }

    public static void main(String[] args) throws Exception {
        var text = """
                The quick brown fox jumps over the lazy dog.
                The dog barked at the fox while the fox ran away.
                Quick thinking by the brown fox saved the day.""";

        var stats = analyze(text, 5);
        System.out.printf("Words: %d, Unique: %d, Avg length: %.1f%n",
                stats.wordCount(), stats.uniqueWords(), stats.avgWordLength());
        System.out.println("Top words: " + stats.topWords());

        var shapes = List.of(
                new Circle(5), new Circle(150),
                new Rectangle(10, 10), new Rectangle(3, 7),
                new Triangle(5, 5, 5), new Triangle(3, 4, 5));
        shapes.forEach(s -> System.out.println(describeShape(s)));

        var tasks = Map.<String, Callable<String>>of(
                "fast", () -> { Thread.sleep(50); return "done-fast"; },
                "slow", () -> { Thread.sleep(200); return "done-slow"; },
                "fail", () -> { throw new RuntimeException("boom"); }
        );

        var results = runAll(tasks);
        results.forEach(r -> System.out.printf("%-6s: %s (%dms)%n",
                r.taskName(), r.result(), r.elapsed().toMillis()));
    }
}
