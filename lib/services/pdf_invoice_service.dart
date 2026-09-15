import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../models/order_model.dart';
import '../models/order_item_model.dart';

class PdfInvoiceService {
  static final brandGreen = PdfColor.fromHex('#55D80F');
  static final brandGreenDark = PdfColor.fromHex('#1FAE3C');
  static final textDark = PdfColor.fromHex('#111827');
  static final textGrey = PdfColor.fromHex('#6B7280');
  static final bgLight = PdfColor.fromHex('#F8FAFC');
  static final borderLight = PdfColor.fromHex('#E7ECF2');

  /// Génère le PDF de la facture au format A4
  static Future<Uint8List> generateA4Invoice({
    required OrderModel order,
    required List<OrderItemModel> items,
    required String invoiceNumber,
  }) async {
    final pdf = pw.Document();

    final dateStr = order.createdAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt!.toLocal())
        : DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final subtotal = items.fold<double>(0, (sum, item) => sum + ((item.price ?? 0) * item.quantity));
    final deliveryFee = (order.totalPrice ?? 0) - subtotal;
    final total = order.totalPrice ?? subtotal;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER ROW
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Company Info
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'GROS DIVERS',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text('Dakar, Sénégal', style: pw.TextStyle(color: textGrey, fontSize: 10)),
                      pw.Text('Téléphone : +221 77 999 02 02', style: pw.TextStyle(color: textGrey, fontSize: 10)),
                    ],
                  ),
                  // Invoice Meta Badge
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'FACTURE',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'N° : $invoiceNumber',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: textDark),
                      ),
                      pw.Text(
                        'Date : $dateStr',
                        style: pw.TextStyle(fontSize: 10, color: textGrey),
                      ),
                      pw.Text(
                        'Commande : #${order.id ?? ""}',
                        style: pw.TextStyle(fontSize: 10, color: textGrey),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 32),
              pw.Divider(color: borderLight, thickness: 1),
              pw.SizedBox(height: 16),

              // CLIENT & PAYMENT DETAILS
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Client Details
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'FACTURÉ À :',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textGrey),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          order.userNom ?? order.userName ?? 'Client Inconnu',
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: textDark),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Tél : ${order.userPhone ?? "Non renseigné"}',
                          style: pw.TextStyle(fontSize: 10, color: textDark),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Adresse : ${order.deliveryAddress ?? order.userAdresse ?? "Livraison en point relais"}',
                          style: pw.TextStyle(fontSize: 10, color: textGrey),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 32),
                  // Payment status
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'STATUT :',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textGrey),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        order.status == 'delivered' ? 'PAYÉ' : 'À PAYER À LA LIVRAISON',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 32),

              // ITEMS TABLE
              pw.Table(
                border: const pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3), // Product name
                  1: const pw.FixedColumnWidth(60), // Qty
                  2: const pw.FixedColumnWidth(100), // Unit Price
                  3: const pw.FixedColumnWidth(100), // Total
                },
                children: [
                  pw.TableRow(
                    children: [
                      pw.Container(
                        alignment: pw.Alignment.centerLeft,
                        padding: const pw.EdgeInsets.symmetric(vertical: 8),
                        child: pw.Text('DESCRIPTION', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textGrey)),
                      ),
                      pw.Container(
                        alignment: pw.Alignment.center,
                        padding: const pw.EdgeInsets.symmetric(vertical: 8),
                        child: pw.Text('QTÉ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textGrey)),
                      ),
                      pw.Container(
                        alignment: pw.Alignment.centerRight,
                        padding: const pw.EdgeInsets.symmetric(vertical: 8),
                        child: pw.Text('PRIX UNIT.', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textGrey)),
                      ),
                      pw.Container(
                        alignment: pw.Alignment.centerRight,
                        padding: const pw.EdgeInsets.symmetric(vertical: 8),
                        child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textGrey)),
                      ),
                    ],
                  ),
                  ...items.map((item) {
                    final unitPrice = item.price ?? 0;
                    final totalItem = unitPrice * item.quantity;
                    return pw.TableRow(
                      children: [
                        pw.Container(
                          alignment: pw.Alignment.centerLeft,
                          padding: const pw.EdgeInsets.symmetric(vertical: 10),
                          child: pw.Text(item.productName ?? 'Produit #${item.productId}', style: pw.TextStyle(fontSize: 10, color: textDark)),
                        ),
                        pw.Container(
                          alignment: pw.Alignment.center,
                          padding: const pw.EdgeInsets.symmetric(vertical: 10),
                          child: pw.Text(item.quantity.toString(), style: pw.TextStyle(fontSize: 10, color: textDark)),
                        ),
                        pw.Container(
                          alignment: pw.Alignment.centerRight,
                          padding: const pw.EdgeInsets.symmetric(vertical: 10),
                          child: pw.Text('${unitPrice.toStringAsFixed(0)} F', style: pw.TextStyle(fontSize: 10, color: textDark)),
                        ),
                        pw.Container(
                          alignment: pw.Alignment.centerRight,
                          padding: const pw.EdgeInsets.symmetric(vertical: 10),
                          child: pw.Text('${totalItem.toStringAsFixed(0)} F', style: pw.TextStyle(fontSize: 10, color: textDark, fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),

              pw.SizedBox(height: 24),

              // TOTALS SECTION
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Payment Info
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Méthode de paiement : Espèces à la livraison',
                        style: pw.TextStyle(fontSize: 9, color: textGrey),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Facture générée numériquement.',
                        style: pw.TextStyle(fontSize: 8, color: textGrey, fontStyle: pw.FontStyle.italic),
                      ),
                    ],
                  ),
                  // Totals
                  pw.Container(
                    width: 200,
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Sous-total :', style: pw.TextStyle(fontSize: 10, color: textGrey)),
                            pw.Text('${subtotal.toStringAsFixed(0)} F', style: pw.TextStyle(fontSize: 10, color: textDark, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        pw.SizedBox(height: 6),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Livraison :', style: pw.TextStyle(fontSize: 10, color: textGrey)),
                            pw.Text('${deliveryFee >= 0 ? deliveryFee.toStringAsFixed(0) : "0"} F', style: pw.TextStyle(fontSize: 10, color: textDark, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        pw.SizedBox(height: 8),
                        pw.Divider(color: borderLight, thickness: 1),
                        pw.SizedBox(height: 8),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'TOTAL :',
                              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: textDark),
                            ),
                            pw.Text(
                              '${total.toStringAsFixed(0)} F',
                              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: textDark),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // FOOTER
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Divider(color: borderLight, thickness: 0.5),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Merci pour votre confiance et à bientôt sur GROS DIVERS !',
                      style: pw.TextStyle(fontSize: 10, color: textGrey, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'GROS DIVERS Dakar - www.gros-divers.sn',
                      style: pw.TextStyle(fontSize: 8, color: textGrey),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Génère le PDF de la facture au format Ticket Thermique (80mm)
  static Future<Uint8List> generateTicketInvoice({
    required OrderModel order,
    required List<OrderItemModel> items,
    required String invoiceNumber,
  }) async {
    final pdf = pw.Document();

    final dateStr = order.createdAt != null
        ? DateFormat('dd/MM/yy HH:mm').format(order.createdAt!.toLocal())
        : DateFormat('dd/MM/yy HH:mm').format(DateTime.now());

    final subtotal = items.fold<double>(0, (sum, item) => sum + ((item.price ?? 0) * item.quantity));
    final deliveryFee = (order.totalPrice ?? 0) - subtotal;
    final total = order.totalPrice ?? subtotal;

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          80 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 6 * PdfPageFormat.mm,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Logo/Brand
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'GROS DIVERS',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Tél: +221 77 999 02 02',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'TICKET FACTURE',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),
              pw.Text('Facture N° : $invoiceNumber', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Text('Date : $dateStr', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Commande ID : #${order.id ?? ""}', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Client : ${order.userNom ?? order.userName ?? "Client"}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              if (order.userPhone != null)
                pw.Text('Tél : ${order.userPhone}', style: const pw.TextStyle(fontSize: 8)),
              if (order.deliveryAddress != null)
                pw.Text('Adresse : ${order.deliveryAddress}', style: const pw.TextStyle(fontSize: 8)),

              pw.SizedBox(height: 8),
              pw.Text('--------------------------------------', style: const pw.TextStyle(fontSize: 8)),

              // ITEMS LIST
              pw.ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final itemTotal = (item.price ?? 0) * item.quantity;
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          item.productName ?? 'Produit #${item.productId}',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              '  ${item.quantity} x ${(item.price ?? 0).toStringAsFixed(0)} F',
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                            pw.Text(
                              '${itemTotal.toStringAsFixed(0)} F',
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              pw.Text('--------------------------------------', style: const pw.TextStyle(fontSize: 8)),

              // TOTALS
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Sous-total:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('${subtotal.toStringAsFixed(0)} F', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Livraison:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('${deliveryFee >= 0 ? deliveryFee.toStringAsFixed(0) : "0"} F', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL NET:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    '${total.toStringAsFixed(0)} F',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),

              pw.SizedBox(height: 12),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('Merci pour votre achat !', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Reçu non remboursable.', style: const pw.TextStyle(fontSize: 7)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Ouvre la boîte de dialogue d'impression système
  static Future<void> printInvoice({
    required OrderModel order,
    required List<OrderItemModel> items,
    required String invoiceNumber,
    required bool isA4,
  }) async {
    final pdfBytes = isA4
        ? await generateA4Invoice(order: order, items: items, invoiceNumber: invoiceNumber)
        : await generateTicketInvoice(order: order, items: items, invoiceNumber: invoiceNumber);

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Facture_${invoiceNumber}.pdf',
    );
  }
}
