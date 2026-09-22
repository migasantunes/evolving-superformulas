// Lays out existing PDFs (first page of each) in a grid with a caption under each, as one vector PDF.
// Uses the iText 2.1.7 that ships with Processing's PDF library, so no extra dependency is needed.
//
// usage: PdfStrip <out.pdf> <width_pt> <cols> <in1.pdf> <label1> [<in2.pdf> <label2> ...]

import com.lowagie.text.Document;
import com.lowagie.text.Rectangle;
import com.lowagie.text.pdf.*;
import java.io.FileOutputStream;

public class PdfStrip {
  public static void main(String[] a) throws Exception {
    String out = a[0];
    float width = Float.parseFloat(a[1]);
    int cols = Integer.parseInt(a[2]);
    int n = (a.length - 3) / 2;
    int rows = (n + cols - 1) / cols;
    float gap = 3, label_h = 9;
    float cell = (width - (cols - 1) * gap) / cols;
    float height = rows * (cell + label_h) + (rows - 1) * gap;

    Document doc = new Document(new Rectangle(width, height), 0, 0, 0, 0);
    PdfWriter writer = PdfWriter.getInstance(doc, new FileOutputStream(out));
    doc.open();
    PdfContentByte cb = writer.getDirectContent();
    BaseFont font = BaseFont.createFont(BaseFont.HELVETICA, BaseFont.WINANSI, false);
    for (int i = 0; i < n; i++) {
      PdfReader reader = new PdfReader(a[3 + 2 * i]);
      PdfImportedPage page = writer.getImportedPage(reader, 1);
      float s = cell / Math.max(page.getWidth(), page.getHeight());
      int row = i / cols, col = i % cols;
      float x = col * (cell + gap);
      float y = height - row * (cell + label_h + gap) - cell;
      cb.addTemplate(page, s, 0, 0, s, x, y);
      cb.setLineWidth(0.3f);
      cb.setGrayStroke(0.75f);
      cb.rectangle(x, y, cell, cell);
      cb.stroke();
      cb.beginText();
      cb.setFontAndSize(font, 6.5f);
      cb.setGrayFill(0.15f);
      cb.showTextAligned(PdfContentByte.ALIGN_CENTER, a[4 + 2 * i], x + cell / 2, y - 7, 0);
      cb.endText();
    }
    doc.close();
  }
}
