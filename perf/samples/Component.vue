<script setup lang="ts">
import { ref, computed, watch, onMounted, type PropType } from "vue";

interface Task {
  id: string;
  title: string;
  completed: boolean;
  priority: "low" | "medium" | "high";
  createdAt: Date;
}

type FilterMode = "all" | "active" | "completed";

const props = defineProps({
  initialTasks: {
    type: Array as PropType<Task[]>,
    default: () => [],
  },
  storageKey: {
    type: String,
    default: "vue-tasks",
  },
});

const emit = defineEmits<{
  (e: "update", tasks: Task[]): void;
  (e: "clear"): void;
}>();

const tasks = ref<Task[]>([...props.initialTasks]);
const newTitle = ref("");
const filter = ref<FilterMode>("all");
const editingId = ref<string | null>(null);
const editText = ref("");

const filteredTasks = computed(() => {
  switch (filter.value) {
    case "active":
      return tasks.value.filter((t) => !t.completed);
    case "completed":
      return tasks.value.filter((t) => t.completed);
    default:
      return tasks.value;
  }
});

const stats = computed(() => {
  const total = tasks.value.length;
  const done = tasks.value.filter((t) => t.completed).length;
  const remaining = total - done;
  const percent = total > 0 ? Math.round((done / total) * 100) : 0;
  return { total, done, remaining, percent };
});

const priorityOrder: Record<Task["priority"], number> = {
  high: 0,
  medium: 1,
  low: 2,
};

const sortedTasks = computed(() =>
  [...filteredTasks.value].sort(
    (a, b) =>
      priorityOrder[a.priority] - priorityOrder[b.priority] ||
      b.createdAt.getTime() - a.createdAt.getTime(),
  ),
);

watch(
  tasks,
  (val) => {
    localStorage.setItem(props.storageKey, JSON.stringify(val));
    emit("update", val);
  },
  { deep: true },
);

onMounted(() => {
  const stored = localStorage.getItem(props.storageKey);
  if (stored) {
    try {
      tasks.value = JSON.parse(stored).map((t: Task) => ({
        ...t,
        createdAt: new Date(t.createdAt),
      }));
    } catch {
      // ignore corrupt storage
    }
  }
});

function addTask() {
  const title = newTitle.value.trim();
  if (!title) return;

  tasks.value.push({
    id: crypto.randomUUID(),
    title,
    completed: false,
    priority: "medium",
    createdAt: new Date(),
  });
  newTitle.value = "";
}

function removeTask(id: string) {
  tasks.value = tasks.value.filter((t) => t.id !== id);
}

function toggleTask(id: string) {
  const task = tasks.value.find((t) => t.id === id);
  if (task) task.completed = !task.completed;
}

function startEditing(task: Task) {
  editingId.value = task.id;
  editText.value = task.title;
}

function finishEditing() {
  if (editingId.value) {
    const task = tasks.value.find((t) => t.id === editingId.value);
    const text = editText.value.trim();
    if (task && text) task.title = text;
    editingId.value = null;
  }
}

function clearCompleted() {
  tasks.value = tasks.value.filter((t) => !t.completed);
  emit("clear");
}

function cyclePriority(task: Task) {
  const cycle: Task["priority"][] = ["low", "medium", "high"];
  const idx = cycle.indexOf(task.priority);
  task.priority = cycle[(idx + 1) % cycle.length];
}
</script>

<template>
  <div class="task-manager">
    <header class="header">
      <h1>Tasks</h1>
      <div class="stats">
        <span class="stats__count">{{ stats.remaining }} remaining</span>
        <div class="stats__bar">
          <div class="stats__fill" :style="{ width: `${stats.percent}%` }" />
        </div>
      </div>
    </header>

    <form class="add-form" @submit.prevent="addTask">
      <input
        v-model="newTitle"
        type="text"
        placeholder="Add a new task…"
        class="add-form__input"
        autofocus
      />
      <button type="submit" class="btn btn--primary" :disabled="!newTitle.trim()">
        Add
      </button>
    </form>

    <nav class="filters" role="tablist">
      <button
        v-for="mode in (['all', 'active', 'completed'] as const)"
        :key="mode"
        role="tab"
        :aria-selected="filter === mode"
        :class="['filters__btn', { 'filters__btn--active': filter === mode }]"
        @click="filter = mode"
      >
        {{ mode }}
      </button>
    </nav>

    <TransitionGroup name="task-list" tag="ul" class="task-list">
      <li v-for="task in sortedTasks" :key="task.id" class="task-item">
        <input
          type="checkbox"
          :checked="task.completed"
          class="task-item__check"
          @change="toggleTask(task.id)"
        />

        <template v-if="editingId === task.id">
          <input
            v-model="editText"
            class="task-item__edit"
            @keyup.enter="finishEditing"
            @keyup.escape="editingId = null"
            @blur="finishEditing"
          />
        </template>
        <template v-else>
          <span
            :class="['task-item__title', { 'task-item__title--done': task.completed }]"
            @dblclick="startEditing(task)"
          >
            {{ task.title }}
          </span>
        </template>

        <button
          :class="['badge', `badge--${task.priority}`]"
          :title="`Priority: ${task.priority}`"
          @click="cyclePriority(task)"
        >
          {{ task.priority }}
        </button>

        <button
          class="task-item__remove"
          aria-label="Remove task"
          @click="removeTask(task.id)"
        >
          ×
        </button>
      </li>
    </TransitionGroup>

    <footer v-if="stats.done > 0" class="footer">
      <button class="btn btn--ghost" @click="clearCompleted">
        Clear {{ stats.done }} completed
      </button>
    </footer>
  </div>
</template>

<style scoped>
.task-manager {
  max-width: 36rem;
  margin: 0 auto;
  padding: 2rem 1rem;
}

.header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 1.5rem;
}

.stats {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  font-size: 0.875rem;
  color: var(--color-text-muted, #6b7280);
}

.stats__bar {
  width: 6rem;
  height: 0.375rem;
  background: var(--color-border, #e5e7eb);
  border-radius: 999px;
  overflow: hidden;
}

.stats__fill {
  height: 100%;
  background: var(--color-primary-500, #6366f1);
  transition: width 300ms ease;
}

.task-list {
  list-style: none;
  padding: 0;
}

.task-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.75rem 0;
  border-bottom: 1px solid var(--color-border, #e5e7eb);
}

.task-item__title--done {
  text-decoration: line-through;
  opacity: 0.5;
}

.task-item__remove {
  margin-left: auto;
  background: none;
  border: none;
  font-size: 1.25rem;
  cursor: pointer;
  opacity: 0;
  transition: opacity 150ms;
}

.task-item:hover .task-item__remove {
  opacity: 0.6;
}

.task-list-enter-active,
.task-list-leave-active {
  transition: all 200ms ease;
}

.task-list-enter-from,
.task-list-leave-to {
  opacity: 0;
  transform: translateX(-1rem);
}
</style>
