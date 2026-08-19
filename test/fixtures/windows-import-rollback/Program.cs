using NikonLink.Windows.Services;

static void Require(bool condition, string message)
{
    if (!condition)
    {
        throw new InvalidOperationException(message);
    }
}

var root = Path.Combine(
    Path.GetTempPath(),
    $"zenche-windows-import-rollback-{Guid.NewGuid():N}");
var sources = Path.Combine(root, "sources");
var library = Path.Combine(root, "library");
Directory.CreateDirectory(sources);
try
{
    var workflow = new CaptureWorkflow(library);
    workflow.Begin(new CaptureSessionConfiguration(
        "Rollback Harness",
        "{session}_{counter}",
        "ZENCHE",
        "test",
        0,
        true));

    var jpeg = Path.Combine(sources, "PAIR.JPG");
    var raw = Path.Combine(sources, "PAIR.NEF");
    var bytes = Enumerable.Range(0, 256 * 1024)
        .Select(index => (byte)(index % 251))
        .ToArray();
    await File.WriteAllBytesAsync(jpeg, bytes);
    await File.WriteAllBytesAsync(raw, bytes);

    var first = await workflow.ImportAsync(jpeg, "Harness", "PAIR");
    Require(workflow.BackupDirectory is not null, "backup directory unavailable");
    Require(workflow.SessionRoot is not null, "session root unavailable");
    var primarySidecar = Path.ChangeExtension(first, ".xmp");
    var backup = Path.Combine(workflow.BackupDirectory!, Path.GetFileName(first));
    var backupSidecar = Path.ChangeExtension(backup, ".xmp");
    var primaryBefore = await File.ReadAllBytesAsync(primarySidecar);
    var backupBefore = await File.ReadAllBytesAsync(backupSidecar);

    var manifest = Path.Combine(workflow.SessionRoot!, "checksums.sha256");
    File.Delete(manifest);
    Directory.CreateDirectory(manifest);
    try
    {
        await workflow.ImportAsync(raw, "Harness", "PAIR");
        throw new InvalidOperationException("manifest-directory fault succeeded");
    }
    catch (InvalidOperationException error) when (
        error.Message.Contains("fault succeeded", StringComparison.Ordinal))
    {
        throw;
    }
    catch
    {
        // Expected: manifest read is fail-closed and triggers rollback.
    }

    Require(
        (await File.ReadAllBytesAsync(primarySidecar)).SequenceEqual(primaryBefore),
        "primary XMP was not restored");
    Require(
        (await File.ReadAllBytesAsync(backupSidecar)).SequenceEqual(backupBefore),
        "backup XMP was not restored");
    Require(
        !File.Exists(Path.Combine(workflow.PrimaryDirectory, "PAIR.nef")),
        "failed primary remained");
    Require(
        !File.Exists(Path.Combine(workflow.BackupDirectory!, "PAIR.nef")),
        "failed backup remained");
    Console.WriteLine("Windows import rollback behavior: PASS");
}
finally
{
    if (Directory.Exists(root))
    {
        Directory.Delete(root, recursive: true);
    }
}
