// Supabase Edge Function: sign-quotation
// Authoritative quotation acceptance, digital signature validation,
// PDF generation (unsigned + signed), and private storage management.

import { createClient } from "npm:@supabase/supabase-js@2";
import { PDFDocument, rgb, StandardFonts } from "npm:pdf-lib";

const allowedOrigins = (Deno.env.get("ALLOWED_ORIGINS") ?? "*")
  .split(",")
  .map((o) => o.trim())
  .filter(Boolean);

function corsHeaders(origin: string | null): Record<string, string> {
  const allowOrigin = allowedOrigins.includes("*")
    ? "*"
    : origin && allowedOrigins.includes(origin)
    ? origin
    : allowedOrigins[0] ?? "null";
  return {
    "Access-Control-Allow-Origin": allowOrigin,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS, GET",
    "Vary": "Origin",
  };
}

function json(status: number, body: unknown, origin: string | null): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
  });
}

function sanitizeText(value: unknown): string {
  if (value === null || value === undefined) return "";
  if (typeof value === "number") return String(value);
  return typeof value === "string" ? value.trim() : "";
}

// Convert base64 string to Uint8Array safely
function base64ToBytes(base64Str: string): Uint8Array {
  // Strip data URL scheme prefix if present (e.g., data:image/png;base64,...)
  const cleanBase64 = base64Str.replace(/^data:image\/[a-z]+;base64,/, "").trim();
  const binaryString = atob(cleanBase64);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes;
}

// Format currency as INR
function formatCurrency(amount: number): string {
  return "Rs. " + amount.toLocaleString("en-IN", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

// Format date nicely
function formatDate(date: Date): string {
  return date.toLocaleDateString("en-IN", {
    year: "numeric",
    month: "short",
    day: "2-digit",
  });
}

function formatDateTime(date: Date): string {
  return date.toLocaleString("en-IN", {
    year: "numeric",
    month: "short",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: true,
  });
}

// Generate authoritative PDF (both unsigned and signed) using pdf-lib
async function generateQuotationPdf(params: {
  isSigned: boolean;
  quotationNumber: string;
  revisionNumber: number;
  quotationDate: Date;
  customerName: string;
  customerPhone: string;
  customerEmail: string;
  vehicleMake: string;
  vehicleModel: string;
  vehicleYear: string;
  vehiclePlate: string;
  vehicleChassis: string;
  items: Array<{
    name: string;
    description: string;
    quantity: number;
    finalValue: number;
    lineTotal: number;
  }>;
  subtotal: number;
  discount: number;
  tax: number;
  total: number;
  terms: string;
  notes: string;
  consentText?: string;
  signedAt?: Date;
  signaturePngBytes?: Uint8Array;
}): Promise<Uint8Array> {
  const pdfDoc = await PDFDocument.create();
  let page = pdfDoc.addPage([595.28, 841.89]); // A4 portrait in points
  const { width, height } = page.getSize();

  const fontRegular = await pdfDoc.embedFont(StandardFonts.Helvetica);
  const fontBold = await pdfDoc.embedFont(StandardFonts.HelveticaBold);
  const fontItalic = await pdfDoc.embedFont(StandardFonts.HelveticaOblique);

  const primaryColor = rgb(0.12, 0.22, 0.42); // AutoTricks Navy
  const secondaryColor = rgb(0.35, 0.40, 0.48); // Slate grey
  const darkTextColor = rgb(0.10, 0.12, 0.15);
  const lightBgColor = rgb(0.96, 0.97, 0.98);
  const borderColor = rgb(0.85, 0.88, 0.92);
  const accentGreen = rgb(0.08, 0.58, 0.32);

  let currentY = height - 40;

  // 1. Header Banner
  page.drawRectangle({
    x: 36,
    y: currentY - 50,
    width: width - 72,
    height: 54,
    color: primaryColor,
  });

  page.drawText("AUTO TRICKS", {
    x: 50,
    y: currentY - 25,
    size: 20,
    font: fontBold,
    color: rgb(1, 1, 1),
  });

  page.drawText("Automotive Service, Performance & Body Engineering", {
    x: 50,
    y: currentY - 42,
    size: 9,
    font: fontRegular,
    color: rgb(0.85, 0.90, 0.98),
  });

  const docTitle = params.isSigned ? "ACCEPTED QUOTATION" : "ESTIMATE / QUOTATION";
  const docTitleWidth = fontBold.widthOfTextAtSize(docTitle, 12);
  page.drawText(docTitle, {
    x: width - 50 - docTitleWidth,
    y: currentY - 26,
    size: 12,
    font: fontBold,
    color: params.isSigned ? rgb(0.35, 0.85, 0.55) : rgb(1, 1, 1),
  });

  const quoteSub = `Rev ${params.revisionNumber} · ${formatDate(params.quotationDate)}`;
  const quoteSubWidth = fontRegular.widthOfTextAtSize(quoteSub, 8);
  page.drawText(quoteSub, {
    x: width - 50 - quoteSubWidth,
    y: currentY - 42,
    size: 8,
    font: fontRegular,
    color: rgb(0.85, 0.90, 0.98),
  });

  currentY -= 70;

  // 2. Info Grid: Quotation & Customer & Vehicle
  const colWidth = (width - 72 - 16) / 2;

  // Customer Card
  page.drawRectangle({
    x: 36,
    y: currentY - 76,
    width: colWidth,
    height: 76,
    color: lightBgColor,
    borderColor: borderColor,
    borderWidth: 1,
  });

  page.drawText("CUSTOMER DETAILS", {
    x: 46,
    y: currentY - 16,
    size: 8,
    font: fontBold,
    color: secondaryColor,
  });
  page.drawText(params.customerName || "Customer", {
    x: 46,
    y: currentY - 32,
    size: 11,
    font: fontBold,
    color: darkTextColor,
  });
  page.drawText(`Phone: ${params.customerPhone || "N/A"}`, {
    x: 46,
    y: currentY - 48,
    size: 9,
    font: fontRegular,
    color: darkTextColor,
  });
  if (params.customerEmail) {
    page.drawText(`Email: ${params.customerEmail}`, {
      x: 46,
      y: currentY - 62,
      size: 8,
      font: fontRegular,
      color: secondaryColor,
    });
  }

  // Vehicle Card
  const col2X = 36 + colWidth + 16;
  page.drawRectangle({
    x: col2X,
    y: currentY - 76,
    width: colWidth,
    height: 76,
    color: lightBgColor,
    borderColor: borderColor,
    borderWidth: 1,
  });

  page.drawText("VEHICLE DETAILS", {
    x: col2X + 10,
    y: currentY - 16,
    size: 8,
    font: fontBold,
    color: secondaryColor,
  });
  const vehicleName = `${params.vehicleMake} ${params.vehicleModel} ${params.vehicleYear}`.trim();
  page.drawText(vehicleName || "Vehicle", {
    x: col2X + 10,
    y: currentY - 32,
    size: 11,
    font: fontBold,
    color: darkTextColor,
  });
  page.drawText(`Plate: ${params.vehiclePlate || "N/A"}`, {
    x: col2X + 10,
    y: currentY - 48,
    size: 9,
    font: fontRegular,
    color: darkTextColor,
  });
  if (params.vehicleChassis) {
    page.drawText(`VIN / Chassis: ${params.vehicleChassis}`, {
      x: col2X + 10,
      y: currentY - 62,
      size: 8,
      font: fontRegular,
      color: secondaryColor,
    });
  }

  currentY -= 92;

  // Quotation Meta Bar
  page.drawText(`Quotation No: ${params.quotationNumber}   |   Revision: ${params.revisionNumber}   |   Issued: ${formatDate(params.quotationDate)}   |   Status: ${params.isSigned ? "ACCEPTED & SIGNED" : "SENT FOR REVIEW"}`, {
    x: 40,
    y: currentY,
    size: 8.5,
    font: fontBold,
    color: primaryColor,
  });

  currentY -= 16;

  // 3. Line Items Table
  const tableX = 36;
  const tableWidth = width - 72;
  const colXIndex = tableX + 8;
  const colXItem = tableX + 32;
  const colXQty = tableX + 310;
  const colXRate = tableX + 370;
  const colXTotal = tableX + 460;

  // Table Header
  page.drawRectangle({
    x: tableX,
    y: currentY - 18,
    width: tableWidth,
    height: 20,
    color: rgb(0.91, 0.93, 0.96),
  });

  page.drawText("#", { x: colXIndex, y: currentY - 14, size: 8, font: fontBold, color: primaryColor });
  page.drawText("ITEM & DESCRIPTION", { x: colXItem, y: currentY - 14, size: 8, font: fontBold, color: primaryColor });
  page.drawText("QTY", { x: colXQty, y: currentY - 14, size: 8, font: fontBold, color: primaryColor });
  page.drawText("UNIT VALUE", { x: colXRate, y: currentY - 14, size: 8, font: fontBold, color: primaryColor });
  page.drawText("TOTAL", { x: colXTotal, y: currentY - 14, size: 8, font: fontBold, color: primaryColor });

  currentY -= 20;

  // Table Rows
  for (let i = 0; i < params.items.length; i++) {
    const item = params.items[i];
    const rowHeight = item.description ? 28 : 20;

    if (currentY - rowHeight < 160) {
      page = pdfDoc.addPage([595.28, 841.89]);
      currentY = height - 40;
    }

    if (i % 2 === 1) {
      page.drawRectangle({
        x: tableX,
        y: currentY - rowHeight + 2,
        width: tableWidth,
        height: rowHeight,
        color: rgb(0.98, 0.98, 0.99),
      });
    }

    // Border line bottom
    page.drawLine({
      start: { x: tableX, y: currentY - rowHeight + 2 },
      end: { x: tableX + tableWidth, y: currentY - rowHeight + 2 },
      color: borderColor,
      thickness: 0.5,
    });

    page.drawText(String(i + 1), { x: colXIndex, y: currentY - 12, size: 8.5, font: fontRegular, color: secondaryColor });
    page.drawText(item.name.substring(0, 48), { x: colXItem, y: currentY - 12, size: 9, font: fontBold, color: darkTextColor });
    if (item.description) {
      page.drawText(item.description.substring(0, 60), { x: colXItem, y: currentY - 22, size: 7.5, font: fontItalic, color: secondaryColor });
    }

    page.drawText(item.quantity.toString(), { x: colXQty, y: currentY - 12, size: 8.5, font: fontRegular, color: darkTextColor });
    page.drawText(formatCurrency(item.finalValue), { x: colXRate, y: currentY - 12, size: 8.5, font: fontRegular, color: darkTextColor });
    page.drawText(formatCurrency(item.lineTotal), { x: colXTotal, y: currentY - 12, size: 9, font: fontBold, color: darkTextColor });

    currentY -= rowHeight;
  }

  currentY -= 12;

  // 4. Financial Summary Matrix (Right aligned box)
  const sumBoxWidth = 220;
  const sumBoxX = width - 36 - sumBoxWidth;
  const sumBoxHeight = params.discount > 0 ? 86 : 72;

  page.drawRectangle({
    x: sumBoxX,
    y: currentY - sumBoxHeight,
    width: sumBoxWidth,
    height: sumBoxHeight,
    color: lightBgColor,
    borderColor: borderColor,
    borderWidth: 1,
  });

  let sumY = currentY - 16;
  page.drawText("Subtotal:", { x: sumBoxX + 12, y: sumY, size: 8.5, font: fontRegular, color: secondaryColor });
  page.drawText(formatCurrency(params.subtotal), { x: sumBoxX + 120, y: sumY, size: 8.5, font: fontRegular, color: darkTextColor });

  if (params.discount > 0) {
    sumY -= 14;
    page.drawText("Discount:", { x: sumBoxX + 12, y: sumY, size: 8.5, font: fontRegular, color: accentGreen });
    page.drawText(`- ${formatCurrency(params.discount)}`, { x: sumBoxX + 120, y: sumY, size: 8.5, font: fontBold, color: accentGreen });
  }

  sumY -= 14;
  page.drawText("Tax (GST):", { x: sumBoxX + 12, y: sumY, size: 8.5, font: fontRegular, color: secondaryColor });
  page.drawText(formatCurrency(params.tax), { x: sumBoxX + 120, y: sumY, size: 8.5, font: fontRegular, color: darkTextColor });

  sumY -= 18;
  page.drawLine({
    start: { x: sumBoxX + 10, y: sumY + 12 },
    end: { x: sumBoxX + sumBoxWidth - 10, y: sumY + 12 },
    color: borderColor,
    thickness: 1,
  });

  page.drawText("TOTAL AMOUNT:", { x: sumBoxX + 12, y: sumY, size: 9.5, font: fontBold, color: primaryColor });
  page.drawText(formatCurrency(params.total), { x: sumBoxX + 115, y: sumY, size: 10.5, font: fontBold, color: primaryColor });

  // Notes on the left side of summary
  if (params.notes) {
    page.drawText("Notes:", { x: 40, y: currentY - 14, size: 8, font: fontBold, color: secondaryColor });
    page.drawText(params.notes.substring(0, 140), { x: 40, y: currentY - 26, size: 7.5, font: fontRegular, color: darkTextColor });
  }

  currentY -= sumBoxHeight + 16;

  // 5. Customer Acceptance & Signature Block (or Unsigned Estimate Notice)
  if (params.isSigned && params.signaturePngBytes) {
    const sigImgWidth = 136;
    const sigImgHeight = 44;
    const sigX = width - 48 - sigImgWidth;
    const maxTextWidth = sigX - 20 - 48; // Leaves 20pt gap between text and signature image

    const consent = params.consentText || "I confirm that I have reviewed this quotation, including the listed work, quantities, prices, taxes, terms and total amount, and I agree to proceed with the quotation as presented.";

    // Multi-line word wrapping strictly bounded to maxTextWidth
    const words = consent.split(/\s+/).filter((w) => w.length > 0);
    const consentLines: string[] = [];
    let currentLine = "";
    const consentFontSize = 7.2;
    const consentLineHeight = 9.2;

    for (const w of words) {
      const candidate = currentLine ? `${currentLine} ${w}` : w;
      if (fontItalic.widthOfTextAtSize(candidate, consentFontSize) <= maxTextWidth) {
        currentLine = candidate;
      } else {
        if (currentLine) consentLines.push(currentLine);
        currentLine = w;
      }
    }
    if (currentLine) consentLines.push(currentLine);

    // Calculate dynamic box height based on actual consent text line count and details
    const textHeight = 26 + (consentLines.length * consentLineHeight) + 8 + 33 + 12;
    const sigBoxHeight = Math.max(116, Math.ceil(textHeight));

    page.drawRectangle({
      x: 36,
      y: currentY - sigBoxHeight,
      width: width - 72,
      height: sigBoxHeight,
      color: rgb(0.97, 0.99, 0.98),
      borderColor: rgb(0.65, 0.85, 0.72),
      borderWidth: 1,
    });

    page.drawText("CUSTOMER ACCEPTANCE & DIGITAL SIGNATURE", {
      x: 48,
      y: currentY - 14,
      size: 9,
      font: fontBold,
      color: accentGreen,
    });

    let textY = currentY - 26;
    for (const line of consentLines) {
      page.drawText(line, {
        x: 48,
        y: textY,
        size: consentFontSize,
        font: fontItalic,
        color: darkTextColor,
      });
      textY -= consentLineHeight;
    }

    const detailsY = textY - 6;
    page.drawText(`Accepted By: ${params.customerName}`, {
      x: 48,
      y: detailsY,
      size: 7.8,
      font: fontBold,
      color: darkTextColor,
    });
    page.drawText(`Signed At: ${params.signedAt ? formatDateTime(params.signedAt) : formatDateTime(new Date())}`, {
      x: 48,
      y: detailsY - 11,
      size: 7.2,
      font: fontRegular,
      color: secondaryColor,
    });
    page.drawText("Signature Method: DRAWN (Biometric Screen Capture)", {
      x: 48,
      y: detailsY - 22,
      size: 7.0,
      font: fontRegular,
      color: secondaryColor,
    });

    // Embed signature PNG image centered vertically in right column
    try {
      const sigImg = await pdfDoc.embedPng(params.signaturePngBytes);
      const sigBlockHeight = 58;
      const sigY = currentY - sigBoxHeight + Math.round((sigBoxHeight - sigBlockHeight) / 2);

      page.drawText("Verified Handwritten Signature", {
        x: sigX,
        y: sigY + sigImgHeight + 4,
        size: 7,
        font: fontBold,
        color: secondaryColor,
      });

      page.drawImage(sigImg, {
        x: sigX,
        y: sigY,
        width: sigImgWidth,
        height: sigImgHeight,
      });

      page.drawLine({
        start: { x: sigX, y: sigY - 2 },
        end: { x: sigX + sigImgWidth, y: sigY - 2 },
        color: rgb(0.70, 0.82, 0.75),
        thickness: 0.5,
      });
    } catch (err) {
      console.error("Signature image embedding error:", err);
    }

    currentY -= sigBoxHeight + 12;
  } else {
    // Unsigned notice
    const noticeHeight = 40;
    page.drawRectangle({
      x: 36,
      y: currentY - noticeHeight,
      width: width - 72,
      height: noticeHeight,
      color: rgb(0.98, 0.98, 0.95),
      borderColor: rgb(0.90, 0.85, 0.70),
      borderWidth: 1,
    });

    page.drawText("QUOTATION ESTIMATE — PENDING CLIENT ACCEPTANCE & SIGNATURE", {
      x: 48,
      y: currentY - 16,
      size: 8.5,
      font: fontBold,
      color: rgb(0.65, 0.45, 0.05),
    });
    page.drawText("This quotation has been prepared by AutoTricks workshop. Review, consent, and digital signature in the client portal are required before work authorization.", {
      x: 48,
      y: currentY - 28,
      size: 7.5,
      font: fontRegular,
      color: darkTextColor,
    });

    currentY -= noticeHeight + 12;
  }

  // 6. Terms & Footer
  if (params.terms) {
    page.drawText(`Terms & Conditions: ${params.terms.substring(0, 150)}`, {
      x: 40,
      y: currentY,
      size: 7,
      font: fontRegular,
      color: secondaryColor,
    });
    currentY -= 12;
  }

  // Bottom Legal line
  page.drawText("AutoTricks Garage & Performance Workshop · Authoritative Document · System Generated", {
    x: 40,
    y: 20,
    size: 7,
    font: fontRegular,
    color: rgb(0.6, 0.65, 0.7),
  });

  return await pdfDoc.save();
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("origin");
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(origin) });
  }

  if (req.method !== "POST") {
    return json(405, { error: "Method not allowed" }, origin);
  }

  // 1. Authenticate user via JWT
  const authHeader = req.headers.get("authorization") || req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return json(401, { error: "Missing or invalid authorization token" }, origin);
  }

  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: { user }, error: userError } = await supabase.auth.getUser(token);
  if (userError || !user) {
    return json(401, { error: "Invalid or expired session" }, origin);
  }

  // 2. Parse request body
  let body: Record<string, unknown>;
  try {
    body = (await req.json()) as Record<string, unknown>;
  } catch {
    return json(400, { error: "Invalid JSON body" }, origin);
  }

  const action = sanitizeText(body.action) || "sign";
  const revisionId = sanitizeText(body.revision_id);

  if (!revisionId) {
    return json(400, { error: "revision_id is required" }, origin);
  }

  // 3. Verify user profile and role
  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("id, role, client_id, full_name")
    .eq("id", user.id)
    .single();

  if (profileError || !profile) {
    return json(403, { error: "User profile not found" }, origin);
  }

  const isAdmin = profile.role === "ADMIN";
  const isClient = profile.role === "CLIENT";

  if (!isAdmin && !isClient) {
    return json(403, { error: "Unauthorized role" }, origin);
  }

  // 4. Fetch authoritative revision, quotation, service request, client, vehicle, items
  const { data: rev, error: revError } = await supabase
    .from("quotation_revisions")
    .select(`
      id,
      quotation_id,
      revision_number,
      status,
      subtotal,
      discount,
      tax,
      total,
      notes,
      terms,
      created_at,
      sent_at,
      accepted_at,
      accepted_by_profile_id,
      acceptance_consent_text,
      quotation_items (
        id,
        name,
        description,
        quantity,
        final_value,
        line_total
      ),
      quotations (
        id,
        quotation_number,
        service_requests (
          id,
          request_number,
          client_id,
          clients (
            id,
            full_name,
            phone,
            email
          ),
          vehicles (
            id,
            make,
            model,
            manufacturing_year,
            registration_number,
            chassis_number
          )
        )
      )
    `)
    .eq("id", revisionId)
    .single();

  if (revError || !rev) {
    return json(404, { error: "Quotation revision not found" }, origin);
  }

  const quote = rev.quotations as Record<string, unknown> | null;
  const sr = quote?.service_requests as Record<string, unknown> | null;
  const client = sr?.clients as Record<string, unknown> | null;
  const vehicle = sr?.vehicles as Record<string, unknown> | null;
  const clientId = sanitizeText(sr?.client_id);
  const quotationId = sanitizeText(rev.quotation_id);
  const revisionNumber = Number(rev.revision_number);

  // Security check: Clients can only access their own quotations
  if (isClient && profile.client_id !== clientId) {
    return json(403, { error: "Forbidden: You do not own this quotation revision" }, origin);
  }

  // --- ACTION: GET DOCUMENT URL ---
  if (action === "get-document-url") {
    const docType = sanitizeText(body.document_type) || "SIGNED_QUOTATION_PDF";
    const bucket = docType === "SIGNED_QUOTATION_PDF" ? "signed-quotation-pdfs" : "quotation-pdfs";

    const { data: doc } = await supabase
      .from("documents")
      .select("id, storage_path")
      .eq("quotation_revision_id", revisionId)
      .eq("document_type", docType)
      .maybeSingle();

    if (!doc) {
      return json(404, { error: `No ${docType} found for this revision` }, origin);
    }

    const { data: signedUrlData, error: urlError } = await supabase.storage
      .from(bucket)
      .createSignedUrl(doc.storage_path, 3600);

    if (urlError || !signedUrlData) {
      return json(500, { error: "Failed to generate signed document URL" }, origin);
    }

    return json(200, {
      ok: true,
      document_id: doc.id,
      storage_path: doc.storage_path,
      signed_url: signedUrlData.signedUrl,
    }, origin);
  }

  // --- ACTION: SIGN QUOTATION ---
  if (action === "sign") {
    if (!isClient) {
      return json(403, { error: "Only clients can sign a quotation" }, origin);
    }

    // Idempotency: Check if already signed by this client
    const { data: existingSig } = await supabase
      .from("quotation_signatures")
      .select("id, signed_at, signature_file")
      .eq("quotation_revision_id", revisionId)
      .maybeSingle();

    if (existingSig) {
      if (body.force_regenerate === true && body.signature_png_base64) {
        const signatureBase64 = sanitizeText(body.signature_png_base64);
        let signatureBytes: Uint8Array;
        try {
          signatureBytes = base64ToBytes(signatureBase64);
        } catch {
          return json(400, { error: "Invalid signature base64 encoding" }, origin);
        }

        const signatureStoragePath = `${clientId}/${revisionId}/signature.png`;
        const signedPdfStoragePath = `${clientId}/${quotationId}/revision-${revisionNumber}-signed.pdf`;

        await supabase.storage
          .from("signatures")
          .upload(signatureStoragePath, signatureBytes, {
            contentType: "image/png",
            upsert: true,
          });

        const rawItems = (rev.quotation_items as Array<Record<string, unknown>>) || [];
        const items = rawItems.map((item) => ({
          name: sanitizeText(item.name),
          description: sanitizeText(item.description),
          quantity: Number(item.quantity) || 1,
          finalValue: Number(item.final_value) || 0,
          lineTotal: Number(item.line_total) || 0,
        }));

        const signedPdfBytes = await generateQuotationPdf({
          isSigned: true,
          quotationNumber: sanitizeText(quote?.quotation_number),
          revisionNumber,
          quotationDate: new Date(sanitizeText(rev.created_at) || Date.now()),
          customerName: sanitizeText(client?.full_name),
          customerPhone: sanitizeText(client?.phone),
          customerEmail: sanitizeText(client?.email),
          vehicleMake: sanitizeText(vehicle?.make),
          vehicleModel: sanitizeText(vehicle?.model),
          vehicleYear: sanitizeText(vehicle?.manufacturing_year),
          vehiclePlate: sanitizeText(vehicle?.registration_number),
          vehicleChassis: sanitizeText(vehicle?.chassis_number),
          items,
          subtotal: Number(rev.subtotal) || 0,
          discount: Number(rev.discount) || 0,
          tax: Number(rev.tax) || 0,
          total: Number(rev.total) || 0,
          terms: sanitizeText(rev.terms),
          notes: sanitizeText(rev.notes),
          consentText: sanitizeText(rev.acceptance_consent_text) || "I confirm that I have reviewed this quotation, including the listed work, quantities, prices, taxes, terms and total amount, and I agree to proceed with the quotation as presented.",
          signedAt: new Date(existingSig.signed_at),
          signaturePngBytes: signatureBytes,
        });

        await supabase.storage
          .from("signed-quotation-pdfs")
          .upload(signedPdfStoragePath, signedPdfBytes, {
            contentType: "application/pdf",
            upsert: true,
          });

        const { data: sData } = await supabase.storage
          .from("signed-quotation-pdfs")
          .createSignedUrl(signedPdfStoragePath, 3600);

        return json(200, {
          ok: true,
          message: "Quotation signed PDF successfully regenerated with updated signature",
          revision_id: revisionId,
          status: "ACCEPTED",
          signed_at: existingSig.signed_at,
          storage_path: signedPdfStoragePath,
          signed_url: sData?.signedUrl,
        }, origin);
      }

      const { data: existingDoc } = await supabase
        .from("documents")
        .select("id, storage_path")
        .eq("quotation_revision_id", revisionId)
        .eq("document_type", "SIGNED_QUOTATION_PDF")
        .maybeSingle();

      let signedUrl = null;
      if (existingDoc) {
        const { data: sData } = await supabase.storage
          .from("signed-quotation-pdfs")
          .createSignedUrl(existingDoc.storage_path, 3600);
        signedUrl = sData?.signedUrl;
      }

      return json(200, {
        ok: true,
        message: "Quotation has already been accepted and signed",
        revision_id: revisionId,
        status: "ACCEPTED",
        signed_at: existingSig.signed_at,
        document_id: existingDoc?.id,
        storage_path: existingDoc?.storage_path,
        signed_url: signedUrl,
      }, origin);
    }

    // Validate revision status: MUST be SENT or VIEWED
    if (rev.status !== "SENT" && rev.status !== "VIEWED") {
      return json(400, {
        error: `Quotation revision cannot be signed in its current status (${rev.status}). Only SENT revisions can be accepted and signed.`,
      }, origin);
    }

    // Validate consent
    const consentGiven = body.consent_given === true;
    const consentText = sanitizeText(body.consent_text);
    if (!consentGiven || consentText.length < 10) {
      return json(400, { error: "Explicit consent confirmation and valid consent statement are required" }, origin);
    }

    // Validate signature PNG
    const signatureBase64 = sanitizeText(body.signature_png_base64);
    if (!signatureBase64) {
      return json(400, { error: "Handwritten signature is required" }, origin);
    }

    let signatureBytes: Uint8Array;
    try {
      signatureBytes = base64ToBytes(signatureBase64);
    } catch {
      return json(400, { error: "Invalid signature base64 encoding" }, origin);
    }

    // PNG magic bytes verification (\x89PNG\r\n\x1a\n)
    if (
      signatureBytes.length < 8 ||
      signatureBytes[0] !== 0x89 ||
      signatureBytes[1] !== 0x50 ||
      signatureBytes[2] !== 0x4e ||
      signatureBytes[3] !== 0x47 ||
      signatureBytes[4] !== 0x0d ||
      signatureBytes[5] !== 0x0a ||
      signatureBytes[6] !== 0x1a ||
      signatureBytes[7] !== 0x0a
    ) {
      return json(400, { error: "Signature must be a valid PNG image" }, origin);
    }

    if (signatureBytes.length > 524288) {
      return json(400, { error: "Signature exceeds maximum allowed size (512 KB)" }, origin);
    }

    // Storage paths adhering to DB policy constraints:
    // Signatures: {client_id}/{revision_id}/signature.png
    // PDFs: {client_id}/{quotation_id}/revision-{revisionNumber}-signed.pdf
    const signatureStoragePath = `${clientId}/${revisionId}/signature.png`;
    const signedPdfStoragePath = `${clientId}/${quotationId}/revision-${revisionNumber}-signed.pdf`;
    const unsignedPdfStoragePath = `${clientId}/${quotationId}/revision-${revisionNumber}.pdf`;

    // 1. Upload signature PNG to private storage bucket 'signatures'
    const { error: sigUploadError } = await supabase.storage
      .from("signatures")
      .upload(signatureStoragePath, signatureBytes, {
        contentType: "image/png",
        upsert: true,
      });

    if (sigUploadError) {
      console.error("Signature storage upload error:", sigUploadError);
      return json(500, { error: "Failed to store signature image in secure storage" }, origin);
    }

    // 2. Prepare authoritative items and data
    const rawItems = (rev.quotation_items as Array<Record<string, unknown>>) || [];
    const items = rawItems.map((item) => ({
      name: sanitizeText(item.name),
      description: sanitizeText(item.description),
      quantity: Number(item.quantity) || 1,
      finalValue: Number(item.final_value) || 0,
      lineTotal: Number(item.line_total) || 0,
    }));

    const signedTimestamp = new Date();

    // 3. Generate unsigned PDF if not exists
    try {
      const { data: existingUnsignedDoc } = await supabase
        .from("documents")
        .select("id")
        .eq("quotation_revision_id", revisionId)
        .eq("document_type", "QUOTATION_PDF")
        .maybeSingle();

      if (!existingUnsignedDoc) {
        const unsignedPdfBytes = await generateQuotationPdf({
          isSigned: false,
          quotationNumber: sanitizeText(quote?.quotation_number),
          revisionNumber,
          quotationDate: new Date(sanitizeText(rev.created_at) || Date.now()),
          customerName: sanitizeText(client?.full_name),
          customerPhone: sanitizeText(client?.phone),
          customerEmail: sanitizeText(client?.email),
          vehicleMake: sanitizeText(vehicle?.make),
          vehicleModel: sanitizeText(vehicle?.model),
          vehicleYear: sanitizeText(vehicle?.manufacturing_year),
          vehiclePlate: sanitizeText(vehicle?.registration_number),
          vehicleChassis: sanitizeText(vehicle?.chassis_number),
          items,
          subtotal: Number(rev.subtotal) || 0,
          discount: Number(rev.discount) || 0,
          tax: Number(rev.tax) || 0,
          total: Number(rev.total) || 0,
          terms: sanitizeText(rev.terms),
          notes: sanitizeText(rev.notes),
        });

        await supabase.storage
          .from("quotation-pdfs")
          .upload(unsignedPdfStoragePath, unsignedPdfBytes, {
            contentType: "application/pdf",
            upsert: true,
          });

        await supabase.from("documents").insert({
          client_id: clientId,
          quotation_revision_id: revisionId,
          document_type: "QUOTATION_PDF",
          storage_path: unsignedPdfStoragePath,
        });
      }
    } catch (pdfErr) {
      console.error("Warning: Unsigned PDF generation failed:", pdfErr);
      // Non-fatal for signing, proceed with signed PDF
    }

    // 4. Generate signed PDF
    let signedPdfBytes: Uint8Array;
    try {
      signedPdfBytes = await generateQuotationPdf({
        isSigned: true,
        quotationNumber: sanitizeText(quote?.quotation_number),
        revisionNumber,
        quotationDate: new Date(sanitizeText(rev.created_at) || Date.now()),
        customerName: sanitizeText(client?.full_name),
        customerPhone: sanitizeText(client?.phone),
        customerEmail: sanitizeText(client?.email),
        vehicleMake: sanitizeText(vehicle?.make),
        vehicleModel: sanitizeText(vehicle?.model),
        vehicleYear: sanitizeText(vehicle?.manufacturing_year),
        vehiclePlate: sanitizeText(vehicle?.registration_number),
        vehicleChassis: sanitizeText(vehicle?.chassis_number),
        items,
        subtotal: Number(rev.subtotal) || 0,
        discount: Number(rev.discount) || 0,
        tax: Number(rev.tax) || 0,
        total: Number(rev.total) || 0,
        terms: sanitizeText(rev.terms),
        notes: sanitizeText(rev.notes),
        consentText,
        signedAt: signedTimestamp,
        signaturePngBytes: signatureBytes,
      });
    } catch (err) {
      console.error("Signed PDF generation error:", err);
      return json(500, { error: "Failed to generate authoritative signed PDF" }, origin);
    }

    // 5. Upload signed PDF to private storage bucket 'signed-quotation-pdfs'
    const { error: pdfUploadError } = await supabase.storage
      .from("signed-quotation-pdfs")
      .upload(signedPdfStoragePath, signedPdfBytes, {
        contentType: "application/pdf",
        upsert: true,
      });

    if (pdfUploadError) {
      console.error("Signed PDF upload error:", pdfUploadError);
      return json(500, { error: "Failed to store signed PDF in secure storage" }, origin);
    }

    // 6. Transition DB state: update revision, insert signature, insert document, approve service request
    // Update quotation revision
    const { error: updateRevError } = await supabase
      .from("quotation_revisions")
      .update({
        status: "ACCEPTED",
        accepted_at: signedTimestamp.toISOString(),
        accepted_by_profile_id: user.id,
        acceptance_consent_text: consentText,
      })
      .eq("id", revisionId);

    if (updateRevError) {
      console.error("Quotation revision update error:", updateRevError);
      return json(500, { error: "Failed to update quotation revision status" }, origin);
    }

    // Insert quotation signature (this fires DB triggers: audit log QUOTATION_SIGNED & notification)
    const { data: sigRow, error: sigInsertError } = await supabase
      .from("quotation_signatures")
      .insert({
        quotation_revision_id: revisionId,
        client_id: clientId,
        profile_id: user.id,
        signature_file: signatureStoragePath,
        signature_method: "DRAWN",
        consent_text: consentText,
        accepted_at: signedTimestamp.toISOString(),
        signed_at: signedTimestamp.toISOString(),
      })
      .select("id, signed_at")
      .single();

    if (sigInsertError || !sigRow) {
      console.error("Signature record insert error:", sigInsertError);
      return json(500, { error: "Failed to record digital signature" }, origin);
    }

    // Insert signed document record into documents table
    const { data: docRow, error: docInsertError } = await supabase
      .from("documents")
      .insert({
        client_id: clientId,
        quotation_revision_id: revisionId,
        document_type: "SIGNED_QUOTATION_PDF",
        storage_path: signedPdfStoragePath,
      })
      .select("id, storage_path")
      .single();

    if (docInsertError) {
      console.error("Document record insert error:", docInsertError);
    }

    // Cancel any leftover DRAFT revisions for this quotation
    await supabase
      .from("quotation_revisions")
      .update({ status: "CANCELLED" })
      .eq("quotation_id", quotationId)
      .eq("status", "DRAFT");

    // Advance service request to APPROVED (Service Job is NOT created)
    const serviceRequestId = sanitizeText(sr?.id);
    if (serviceRequestId) {
      await supabase
        .from("service_requests")
        .update({ status: "APPROVED" })
        .eq("id", serviceRequestId)
        .not("status", "in", '("CONVERTED_TO_JOB","CANCELLED")');
    }

    // 7. Generate a 1-hour signed download URL for the client
    const { data: signedUrlData } = await supabase.storage
      .from("signed-quotation-pdfs")
      .createSignedUrl(signedPdfStoragePath, 3600);

    return json(200, {
      ok: true,
      message: "Quotation successfully accepted and signed",
      revision_id: revisionId,
      status: "ACCEPTED",
      signed_at: sigRow.signed_at,
      document_id: docRow?.id,
      storage_path: signedPdfStoragePath,
      signed_url: signedUrlData?.signedUrl ?? null,
    }, origin);
  }

  return json(400, { error: `Unknown action: ${action}` }, origin);
});
