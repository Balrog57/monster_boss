using WaveEngine.Common.IO;

// stub: IIOManager (adaptateur Android de WaveEngine) -> lecture de fichiers "Content/..." sur disque; le reste n'est jamais appele par la logique.
sealed class ContentIO : IIOManager
{
    readonly string root;
    public ContentIO(string root) { this.root = root; }
    string P(string path) => Path.Combine(root, path.Replace('/', Path.DirectorySeparatorChar));
    public Stream OpenContentFile(string path) => File.OpenRead(P(path));
    public bool ExistsContentFile(string path) => File.Exists(P(path));
    public string[] GetContentFileNames(string path) => Directory.Exists(P(path)) ? Directory.GetFiles(P(path)).Select(Path.GetFileName).ToArray() : new string[0];
    public string[] GetContentDirectories(string path) => Directory.Exists(P(path)) ? Directory.GetDirectories(P(path)).Select(Path.GetFileName).ToArray() : new string[0];
    public bool ExistsStorageFile(string path) => false;
    public Stream CreateStorageFile(string path) => throw new NotSupportedException();
    public Stream OpenStorageFile(string path, WaveEngine.Common.IO.FileMode mode) => throw new NotSupportedException();
    public Stream OpenStorageFile(string path, WaveEngine.Common.IO.FileMode mode, WaveEngine.Common.IO.FileAccess access) => throw new NotSupportedException();
    public void DeleteStorageFile(string path) { }
    public void MoveStorageFile(string oldPath, string newPath) { }
    public DateTimeOffset GetCreationTime(string path) => DateTimeOffset.UnixEpoch;
    public string[] GetFileNames(string searchPattern) => new string[0];
    public void CreateDirectory(string directoryName) { }
    public void DeleteDirectory(string directoryName) { }
    public bool DirectoryExists(string directoryName) => false;
    public string[] GetDirectoryNames(string searchPattern) => new string[0];
    public byte[] GetRGBABytes(Stream imageStream, out int imageWidth, out int imageHeight) { imageWidth = imageHeight = 0; return new byte[0]; }
    public void SavePictureToLibrary(string path) { }
    public void SavePictureToLibrary(string fileName, Stream fileStream) { }
    public void Dispose() { }
}
