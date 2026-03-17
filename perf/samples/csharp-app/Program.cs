using System.Collections.Concurrent;

namespace PerfSample;

public sealed record Customer(
  Guid Id,
  string Name,
  decimal Balance,
  string Tier
);

public sealed record Invoice(
  string Number,
  Guid CustomerId,
  decimal Amount,
  DateTime IssuedAt
);

public static class Program
{
  public static async Task Main()
  {
    var customers = SeedCustomers();
    var invoices = SeedInvoices(customers);

    var summaries = await BuildSummariesAsync(customers, invoices);
    foreach (
      var summary in summaries.OrderByDescending(item => item.TotalAmount)
    )
    {
      Console.WriteLine(
        $"{summary.Name, -12} {summary.Tier, -6} invoices={summary.InvoiceCount, 2} total={summary.TotalAmount, 7:C}"
      );
    }
  }

  private static List<Customer> SeedCustomers() =>
    [
      new(Guid.NewGuid(), "Avery", 1_240.50m, "gold"),
      new(Guid.NewGuid(), "Mika", 318.00m, "silver"),
      new(Guid.NewGuid(), "Noor", 5_902.15m, "platinum"),
      new(Guid.NewGuid(), "Sage", 780.40m, "gold"),
    ];

  private static List<Invoice> SeedInvoices(IEnumerable<Customer> customers)
  {
    var now = DateTime.UtcNow;
    return customers
      .SelectMany(
        (customer, index) =>
          Enumerable
            .Range(1, 3)
            .Select(offset => new Invoice(
              Number: $"INV-{index + 1:D2}-{offset:D2}",
              CustomerId: customer.Id,
              Amount: decimal.Round(customer.Balance / (offset + 1), 2),
              IssuedAt: now.AddDays(-(index * 7 + offset))
            ))
      )
      .ToList();
  }

  private static async Task<IReadOnlyList<CustomerSummary>> BuildSummariesAsync(
    IReadOnlyCollection<Customer> customers,
    IReadOnlyCollection<Invoice> invoices
  )
  {
    var totals = new ConcurrentDictionary<Guid, decimal>();

    await Parallel.ForEachAsync(
      invoices,
      async (invoice, cancellationToken) =>
      {
        await Task.Delay(5, cancellationToken);
        totals.AddOrUpdate(
          invoice.CustomerId,
          invoice.Amount,
          (_, current) => current + invoice.Amount
        );
      }
    );

    return customers
      .Select(customer =>
      {
        var customerInvoices = invoices
          .Where(invoice => invoice.CustomerId == customer.Id)
          .ToList();
        totals.TryGetValue(customer.Id, out var totalAmount);
        return new CustomerSummary(
          customer.Name,
          customer.Tier,
          customerInvoices.Count,
          totalAmount,
          customerInvoices.MaxBy(invoice => invoice.IssuedAt)?.IssuedAt
        );
      })
      .ToList();
  }
}

public sealed record CustomerSummary(
  string Name,
  string Tier,
  int InvoiceCount,
  decimal TotalAmount,
  DateTime? LatestInvoiceAt
);
