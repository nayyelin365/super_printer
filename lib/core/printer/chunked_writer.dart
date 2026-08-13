/// Writes a byte payload to a transport in fixed-size chunks with a small
/// delay between them.
///
/// Classic Bluetooth SPP and USB-serial links can drop or corrupt data when
/// a large payload (a full label bitmap can be 50-100KB as ZPL hex) is
/// pushed through the OS socket buffer in one call. Chunking with a short
/// pause gives the receiving printer's buffer time to drain.
class ChunkedWriter {
  const ChunkedWriter._();

  static Future<void> write(
    List<int> data,
    Future<void> Function(List<int> chunk) writeChunk, {
    int chunkSize = 512,
    int delayMs = 20,
  }) async {
    for (var offset = 0; offset < data.length; offset += chunkSize) {
      final end =
          (offset + chunkSize < data.length) ? offset + chunkSize : data.length;
      await writeChunk(data.sublist(offset, end));
      if (end < data.length && delayMs > 0) {
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
  }
}
