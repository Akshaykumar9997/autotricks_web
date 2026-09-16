// Public website "book a service" endpoint.
// Anonymous visitors never write to core tables directly: this function
// validates the form, throttles repeat submissions per phone number and
// inserts a WEBSITE service request (status NEW, no client/vehicle) using
// the service role. The submitted form is preserved in original_submission.
import { createClient } from "npm:@supabase/supabase-js@2";

const MAX_BODY_BYTES = 16_000;
const MAX_PER_PHONE_PER_HOUR = 5;

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
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}

function json(status: number, body: unknown, origin: string | null): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
  });
}

type Submission = {
  customer_name: string;
  phone: string;
  email: string | null;
  car_make: string;
  car_model: string;
  manufacturing_year: number | null;
  chassis_number: string | null;
  registration_number: string | null;
  current_location: string;
  service_description: string;
};

function text(value: unknown): string {
  if (typeof value === "number") return String(value);
  return typeof value === "string" ? value.trim().replace(/\s+/g, " ") : "";
}

function validate(input: Record<string, unknown>): { data?: Submission; errors?: Record<string, string> } {
  const errors: Record<string, string> = {};
  const currentYear = new Date().getFullYear();

  const customer_name = text(input.customer_name);
  if (customer_name.length < 2 || customer_name.length > 100) {
    errors.customer_name = "Enter your name (2-100 characters).";
  }

  const phone = text(input.phone).replace(/[\s\-().]/g, "");
  if (!/^\+?[0-9]{10,15}$/.test(phone)) {
    errors.phone = "Enter a valid phone number.";
  }

  const emailInput = text(input.email).toLowerCase();
  const email = emailInput === "" ? null : emailInput;
  if (email !== null && (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email))) {
    errors.email = "Enter a valid email address.";
  }

  const car_make = text(input.car_make);
  if (car_make.length < 1 || car_make.length > 60) errors.car_make = "Enter the car make.";

  const car_model = text(input.car_model);
  if (car_model.length < 1 || car_model.length > 60) errors.car_model = "Enter the car model.";

  let manufacturing_year: number | null = null;
  const yearInput = text(input.manufacturing_year);
  if (yearInput !== "") {
    const year = Number(yearInput);
    if (!Number.isInteger(year) || year < 1886 || year > currentYear + 1) {
      errors.manufacturing_year = "Enter a valid manufacturing year.";
    } else {
      manufacturing_year = year;
    }
  }

  const chassisInput = text(input.chassis_number).toUpperCase().replace(/[\s-]/g, "");
  const chassis_number = chassisInput === "" ? null : chassisInput;
  if (chassis_number !== null && !/^[A-Z0-9]{5,25}$/.test(chassis_number)) {
    errors.chassis_number = "Enter a valid chassis number.";
  }

  const registrationInput = text(input.registration_number).toUpperCase().replace(/[\s-]/g, "");
  const registration_number = registrationInput === "" ? null : registrationInput;
  if (registration_number !== null && !/^[A-Z0-9]{4,15}$/.test(registration_number)) {
    errors.registration_number = "Enter a valid registration number.";
  }

  const current_location = text(input.current_location);
  if (current_location.length < 3 || current_location.length > 300) {
    errors.current_location = "Enter your current location.";
  }

  const service_description = typeof input.service_description === "string" ? input.service_description.trim() : "";
  if (service_description.length < 5 || service_description.length > 2000) {
    errors.service_description = "Describe the service you need (5-2000 characters).";
  }

  if (Object.keys(errors).length > 0) return { errors };
  return {
    data: {
      customer_name,
      phone,
      email,
      car_make,
      car_model,
      manufacturing_year,
      chassis_number,
      registration_number,
      current_location,
      service_description,
    },
  };
}

Deno.serve(async (req) => {
  const origin = req.headers.get("Origin");

  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(origin) });
  }
  if (req.method !== "POST") {
    return json(405, { error: "Method not allowed" }, origin);
  }
  if (!allowedOrigins.includes("*") && origin && !allowedOrigins.includes(origin)) {
    return json(403, { error: "Origin not allowed" }, origin);
  }

  const raw = await req.text();
  if (raw.length > MAX_BODY_BYTES) {
    return json(413, { error: "Request too large" }, origin);
  }

  let body: Record<string, unknown>;
  try {
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error("not an object");
    body = parsed as Record<string, unknown>;
  } catch {
    return json(400, { error: "Invalid JSON body" }, origin);
  }

  // Honeypot: a hidden field real visitors never fill in.
  if (text(body.company_website) !== "") {
    return json(202, { ok: true }, origin);
  }

  const { data, errors } = validate(body);
  if (!data) {
    return json(422, { error: "Validation failed", fields: errors }, origin);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );

  const since = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const { count, error: countError } = await supabase
    .from("service_requests")
    .select("id", { count: "exact", head: true })
    .eq("source", "WEBSITE")
    .eq("original_submission->>phone", data.phone)
    .gte("created_at", since);

  if (countError) {
    console.error("throttle check failed", countError);
    return json(500, { error: "Could not submit the request. Please try again." }, origin);
  }
  if ((count ?? 0) >= MAX_PER_PHONE_PER_HOUR) {
    return json(429, { error: "Too many requests for this phone number. Please try again later or call us." }, origin);
  }

  const { data: row, error } = await supabase
    .from("service_requests")
    .insert({
      source: "WEBSITE",
      original_submission: { ...data, submitted_at: new Date().toISOString() },
    })
    .select("request_number, created_at")
    .single();

  if (error || !row) {
    console.error("service request insert failed", error);
    return json(500, { error: "Could not submit the request. Please try again." }, origin);
  }

  return json(201, { request_number: row.request_number, submitted_at: row.created_at }, origin);
});
