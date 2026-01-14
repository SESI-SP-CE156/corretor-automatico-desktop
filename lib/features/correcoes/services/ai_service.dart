import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';

class ImageUtils {
  /// Converte a imagem crua do PDF (BGRA/RGBA) para img.Image do Dart
  static img.Image? fromPdfImage(PdfImage pdfImage) {
    try {
      // PdfImage geralmente vem como BGRA ou RGBA dependendo da plataforma.
      // Vamos assumir RGBA para simplificar, mas pode precisar de inversão de canais B/R.
      return img.Image.fromBytes(
        width: pdfImage.width,
        height: pdfImage.height,
        bytes: pdfImage.pixels.buffer,
        order: img.ChannelOrder.bgra, // Windows/Linux costuma ser BGRA
        numChannels: 4,
      );
    } catch (e) {
      print("Erro na conversão PDF->Image: $e");
      return null;
    }
  }

  /// Converte img.Image para JPG bytes (Necessário para o YOLO do flutter_vision)
  static Uint8List toJpgBytes(img.Image image) {
    return img.encodeJpg(image, quality: 80);
  }

  /// Prepara o recorte de UMA questão para o modelo OMR
  /// Input: Imagem recortada da linha da questão
  /// Output: Float32List normalizado [32 * 150 * 1]
  static Float32List prepareForOMR(img.Image strip) {
    // 1. Redimensiona para o input do modelo (150 largura, 32 altura)
    // Nota: O Python usava (32, 150). Verifique se é HxW ou WxH.
    // Padrão visual é W=150, H=32.
    img.Image resized = img.copyResize(strip, width: 150, height: 32);

    // 2. Escala de cinza
    img.Image grayscale = img.grayscale(resized);

    // 3. Normalização (0.0 a 1.0) e Flatten
    var floatList = Float32List(32 * 150 * 1);
    var index = 0;

    for (var y = 0; y < grayscale.height; y++) {
      for (var x = 0; x < grayscale.width; x++) {
        var pixel = grayscale.getPixel(x, y);
        // pixel.r já é o valor de cinza (0-255)
        floatList[index++] = pixel.r / 255.0;
      }
    }
    return floatList;
  }
}
