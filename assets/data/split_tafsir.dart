import 'dart:convert';
import 'dart:io';

void main() async {
  // 1. Emri i skedarit burim
  final inputPath = 'sq-saadi.json';
  final outputDir = Directory('tafsir_splitted');

  // Krijo folderin e daljes nëse nuk ekziston
  if (!await outputDir.exists()) {
    await outputDir.create();
  }

  print('Duke lexuar skedarin... Ju lutem prisni.');

  try {
    // 2. Lexo skedarin e madh
    final file = File(inputPath);
    final content = await file.readAsString();
    final Map<String, dynamic> fullData = jsonDecode(content);

    // 3. Struktura për të grupuar të dhënat: { surahId: { ayahKey: data } }
    Map<int, Map<String, dynamic>> groupedData = {};

    print('Duke procesuar ajetet...');

    fullData.forEach((key, value) {
      // Key është në formatin "1:1", "114:6" etj.
      final surahId = int.parse(key.split(':').first);
      
      if (!groupedData.containsKey(surahId)) {
        groupedData[surahId] = {};
      }
      
      groupedData[surahId]![key] = value;
    });

    // 4. Shkruaj 114 skedarët
    print('Duke shkruar skedarët individualë...');

    for (var i = 1; i <= 114; i++) {
      if (groupedData.containsKey(i)) {
        final surahFile = File('${outputDir.path}/$i.json');
        await surahFile.writeAsString(jsonEncode(groupedData[i]));
      }
    }

    print('SUKSES! U gjeneruan ${groupedData.length} skedarë në folderin: ${outputDir.path}');
  } catch (e) {
    print('GABIM: $e');
  }
}
