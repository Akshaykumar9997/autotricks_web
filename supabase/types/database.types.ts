export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      audit_logs: {
        Row: {
          action: string
          actor_profile_id: string | null
          created_at: string
          entity_id: string | null
          entity_type: string
          id: string
          metadata: Json | null
        }
        Insert: {
          action: string
          actor_profile_id?: string | null
          created_at?: string
          entity_id?: string | null
          entity_type: string
          id?: string
          metadata?: Json | null
        }
        Update: {
          action?: string
          actor_profile_id?: string | null
          created_at?: string
          entity_id?: string | null
          entity_type?: string
          id?: string
          metadata?: Json | null
        }
        Relationships: [
          {
            foreignKeyName: "audit_logs_actor_profile_id_fkey"
            columns: ["actor_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      clients: {
        Row: {
          address: string | null
          city: string | null
          created_at: string
          email: string | null
          full_name: string
          id: string
          is_active: boolean
          notes: string | null
          phone: string
          pincode: string | null
          state: string | null
          updated_at: string
        }
        Insert: {
          address?: string | null
          city?: string | null
          created_at?: string
          email?: string | null
          full_name: string
          id?: string
          is_active?: boolean
          notes?: string | null
          phone: string
          pincode?: string | null
          state?: string | null
          updated_at?: string
        }
        Update: {
          address?: string | null
          city?: string | null
          created_at?: string
          email?: string | null
          full_name?: string
          id?: string
          is_active?: boolean
          notes?: string | null
          phone?: string
          pincode?: string | null
          state?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      documents: {
        Row: {
          client_id: string
          created_at: string
          document_type: Database["public"]["Enums"]["document_type"]
          id: string
          quotation_revision_id: string | null
          service_job_id: string | null
          storage_bucket: string | null
          storage_path: string
        }
        Insert: {
          client_id: string
          created_at?: string
          document_type: Database["public"]["Enums"]["document_type"]
          id?: string
          quotation_revision_id?: string | null
          service_job_id?: string | null
          storage_bucket?: string | null
          storage_path: string
        }
        Update: {
          client_id?: string
          created_at?: string
          document_type?: Database["public"]["Enums"]["document_type"]
          id?: string
          quotation_revision_id?: string | null
          service_job_id?: string | null
          storage_bucket?: string | null
          storage_path?: string
        }
        Relationships: [
          {
            foreignKeyName: "documents_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "admin_clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "documents_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "client_portal_clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "documents_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "documents_quotation_revision_id_fkey"
            columns: ["quotation_revision_id"]
            isOneToOne: false
            referencedRelation: "quotation_revisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "documents_service_job_fk"
            columns: ["service_job_id"]
            isOneToOne: false
            referencedRelation: "service_jobs"
            referencedColumns: ["id"]
          },
        ]
      }
      email_notifications: {
        Row: {
          created_at: string
          error_message: string | null
          failed_at: string | null
          id: string
          notification_type: Database["public"]["Enums"]["notification_type"]
          profile_id: string
          recipient_email: string
          related_entity_id: string | null
          related_entity_type: string | null
          sent_at: string | null
          status: Database["public"]["Enums"]["email_delivery_status"]
          subject: string
        }
        Insert: {
          created_at?: string
          error_message?: string | null
          failed_at?: string | null
          id?: string
          notification_type: Database["public"]["Enums"]["notification_type"]
          profile_id: string
          recipient_email: string
          related_entity_id?: string | null
          related_entity_type?: string | null
          sent_at?: string | null
          status?: Database["public"]["Enums"]["email_delivery_status"]
          subject: string
        }
        Update: {
          created_at?: string
          error_message?: string | null
          failed_at?: string | null
          id?: string
          notification_type?: Database["public"]["Enums"]["notification_type"]
          profile_id?: string
          recipient_email?: string
          related_entity_id?: string | null
          related_entity_type?: string | null
          sent_at?: string | null
          status?: Database["public"]["Enums"]["email_delivery_status"]
          subject?: string
        }
        Relationships: [
          {
            foreignKeyName: "email_notifications_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          created_at: string
          entity_id: string | null
          entity_type: string | null
          id: string
          is_read: boolean
          message: string
          profile_id: string
          read_at: string | null
          title: string
          type: Database["public"]["Enums"]["notification_type"]
        }
        Insert: {
          created_at?: string
          entity_id?: string | null
          entity_type?: string | null
          id?: string
          is_read?: boolean
          message: string
          profile_id: string
          read_at?: string | null
          title: string
          type: Database["public"]["Enums"]["notification_type"]
        }
        Update: {
          created_at?: string
          entity_id?: string | null
          entity_type?: string | null
          id?: string
          is_read?: boolean
          message?: string
          profile_id?: string
          read_at?: string | null
          title?: string
          type?: Database["public"]["Enums"]["notification_type"]
        }
        Relationships: [
          {
            foreignKeyName: "notifications_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      products: {
        Row: {
          category: string | null
          created_at: string
          default_price: number
          description: string | null
          id: string
          is_active: boolean
          name: string
          updated_at: string
        }
        Insert: {
          category?: string | null
          created_at?: string
          default_price: number
          description?: string | null
          id?: string
          is_active?: boolean
          name: string
          updated_at?: string
        }
        Update: {
          category?: string | null
          created_at?: string
          default_price?: number
          description?: string | null
          id?: string
          is_active?: boolean
          name?: string
          updated_at?: string
        }
        Relationships: []
      }
      profiles: {
        Row: {
          client_id: string | null
          created_at: string
          full_name: string
          id: string
          role: Database["public"]["Enums"]["user_role"]
          updated_at: string
        }
        Insert: {
          client_id?: string | null
          created_at?: string
          full_name: string
          id: string
          role: Database["public"]["Enums"]["user_role"]
          updated_at?: string
        }
        Update: {
          client_id?: string | null
          created_at?: string
          full_name?: string
          id?: string
          role?: Database["public"]["Enums"]["user_role"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "profiles_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "admin_clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "profiles_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "client_portal_clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "profiles_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
        ]
      }
      quotation_change_requests: {
        Row: {
          admin_response: string | null
          client_id: string
          created_at: string
          id: string
          message: string
          profile_id: string
          quotation_revision_id: string
          responded_at: string | null
          status: Database["public"]["Enums"]["change_request_status"]
        }
        Insert: {
          admin_response?: string | null
          client_id: string
          created_at?: string
          id?: string
          message: string
          profile_id: string
          quotation_revision_id: string
          responded_at?: string | null
          status?: Database["public"]["Enums"]["change_request_status"]
        }
        Update: {
          admin_response?: string | null
          client_id?: string
          created_at?: string
          id?: string
          message?: string
          profile_id?: string
          quotation_revision_id?: string
          responded_at?: string | null
          status?: Database["public"]["Enums"]["change_request_status"]
        }
        Relationships: [
          {
            foreignKeyName: "quotation_change_requests_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "admin_clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "quotation_change_requests_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "client_portal_clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "quotation_change_requests_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "quotation_change_requests_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "quotation_change_requests_quotation_revision_id_fkey"
            columns: ["quotation_revision_id"]
            isOneToOne: false
            referencedRelation: "quotation_revisions"
            referencedColumns: ["id"]
          },
        ]
      }
      quotation_items: {
        Row: {
          approximate_value: number | null
          catalogue_product_id: string | null
          created_at: string
          description: string | null
          final_value: number
          id: string
          line_total: number
          name: string
          quantity: number
          quotation_revision_id: string
          updated_at: string
        }
        Insert: {
          approximate_value?: number | null
          catalogue_product_id?: string | null
          created_at?: string
          description?: string | null
          final_value: number
          id?: string
          line_total: number
          name: string
          quantity: number
          quotation_revision_id: string
          updated_at?: string
        }
        Update: {
          approximate_value?: number | null
          catalogue_product_id?: string | null
          created_at?: string
          description?: string | null
          final_value?: number
          id?: string
          line_total?: number
          name?: string
          quantity?: number
          quotation_revision_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "quotation_items_catalogue_product_id_fkey"
            columns: ["catalogue_product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "quotation_items_quotation_revision_id_fkey"
            columns: ["quotation_revision_id"]
            isOneToOne: false
            referencedRelation: "quotation_revisions"
            referencedColumns: ["id"]
          },
        ]
      }
      quotation_revisions: {
        Row: {
          acceptance_consent_text: string | null
          accepted_at: string | null
          accepted_by_profile_id: string | null
          created_at: string
          created_by: string
          discount: number
          id: string
          notes: string | null
          quotation_id: string
          rejected_at: string | null
          rejection_reason: string | null
          revision_number: number
          sent_at: string | null
          status: Database["public"]["Enums"]["quotation_revision_status"]
          subtotal: number
          tax: number
          terms: string | null
          total: number
          updated_at: string
        }
        Insert: {
          acceptance_consent_text?: string | null
          accepted_at?: string | null
          accepted_by_profile_id?: string | null
          created_at?: string
          created_by: string
          discount?: number
          id?: string
          notes?: string | null
          quotation_id: string
          rejected_at?: string | null
          rejection_reason?: string | null
          revision_number: number
          sent_at?: string | null
          status?: Database["public"]["Enums"]["quotation_revision_status"]
          subtotal?: number
          tax?: number
          terms?: string | null
          total?: number
          updated_at?: string
        }
        Update: {
          acceptance_consent_text?: string | null
          accepted_at?: string | null
          accepted_by_profile_id?: string | null
          created_at?: string
          created_by?: string
          discount?: number
          id?: string
          notes?: string | null
          quotation_id?: string
          rejected_at?: string | null
          rejection_reason?: string | null
          revision_number?: number
          sent_at?: string | null
          status?: Database["public"]["Enums"]["quotation_revision_status"]
          subtotal?: number
          tax?: number
          terms?: string | null
          total?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "quotation_revisions_accepted_by_profile_id_fkey"
            columns: ["accepted_by_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "quotation_revisions_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "quotation_revisions_quotation_id_fkey"
            columns: ["quotation_id"]
            isOneToOne: false
            referencedRelation: "quotations"
            referencedColumns: ["id"]
          },
        ]
      }
      quotation_signatures: {
        Row: {
          accepted_at: string
          client_id: string
          consent_text: string
          created_at: string
          id: string
          profile_id: string
          quotation_revision_id: string
          signature_file: string
          signature_method: Database["public"]["Enums"]["signature_method"]
          signed_at: string
        }
        Insert: {
          accepted_at: string
          client_id: string
          consent_text: string
          created_at?: string
          id?: string
          profile_id: string
          quotation_revision_id: string
          signature_file: string
          signature_method?: Database["public"]["Enums"]["signature_method"]
          signed_at: string
        }
        Update: {
          accepted_at?: string
          client_id?: string
          consent_text?: string
          created_at?: string
          id?: string
          profile_id?: string
          quotation_revision_id?: string
          signature_file?: string
          signature_method?: Database["public"]["Enums"]["signature_method"]
          signed_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "quotation_signatures_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "admin_clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "quotation_signatures_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "client_portal_clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "quotation_signatures_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "quotation_signatures_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "quotation_signatures_quotation_revision_id_fkey"
            columns: ["quotation_revision_id"]
            isOneToOne: true
            referencedRelation: "quotation_revisions"
            referencedColumns: ["id"]
          },
        ]
      }
      quotations: {
        Row: {
          created_at: string
          created_by: string
          id: string
          quotation_number: string
          service_request_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by: string
          id?: string
          quotation_number?: string
          service_request_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string
          id?: string
          quotation_number?: string
          service_request_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "quotations_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "quotations_service_request_id_fkey"
            columns: ["service_request_id"]
            isOneToOne: true
            referencedRelation: "admin_service_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "quotations_service_request_id_fkey"
            columns: ["service_request_id"]
            isOneToOne: true
            referencedRelation: "client_portal_service_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "quotations_service_request_id_fkey"
            columns: ["service_request_id"]
            isOneToOne: true
            referencedRelation: "service_requests"
            referencedColumns: ["id"]
          },
        ]
      }
      service_jobs: {
        Row: {
          completed_at: string | null
          created_at: string
          id: string
          job_number: string
          quotation_revision_id: string
          scheduled_at: string | null
          service_request_id: string
          started_at: string | null
          status: Database["public"]["Enums"]["service_job_status"]
          updated_at: string
          vehicle_id: string
        }
        Insert: {
          completed_at?: string | null
          created_at?: string
          id?: string
          job_number?: string
          quotation_revision_id: string
          scheduled_at?: string | null
          service_request_id: string
          started_at?: string | null
          status?: Database["public"]["Enums"]["service_job_status"]
          updated_at?: string
          vehicle_id: string
        }
        Update: {
          completed_at?: string | null
          created_at?: string
          id?: string
          job_number?: string
          quotation_revision_id?: string
          scheduled_at?: string | null
          service_request_id?: string
          started_at?: string | null
          status?: Database["public"]["Enums"]["service_job_status"]
          updated_at?: string
          vehicle_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "service_jobs_quotation_revision_id_fkey"
            columns: ["quotation_revision_id"]
            isOneToOne: false
            referencedRelation: "quotation_revisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_jobs_service_request_id_fkey"
            columns: ["service_request_id"]
            isOneToOne: true
            referencedRelation: "admin_service_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_jobs_service_request_id_fkey"
            columns: ["service_request_id"]
            isOneToOne: true
            referencedRelation: "client_portal_service_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_jobs_service_request_id_fkey"
            columns: ["service_request_id"]
            isOneToOne: true
            referencedRelation: "service_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_jobs_vehicle_id_fkey"
            columns: ["vehicle_id"]
            isOneToOne: false
            referencedRelation: "vehicles"
            referencedColumns: ["id"]
          },
        ]
      }
      service_requests: {
        Row: {
          admin_notes: string | null
          client_id: string | null
          created_at: string
          created_by: string | null
          id: string
          original_submission: Json | null
          request_number: string
          source: Database["public"]["Enums"]["request_source"]
          status: Database["public"]["Enums"]["service_request_status"]
          updated_at: string
          vehicle_id: string | null
        }
        Insert: {
          admin_notes?: string | null
          client_id?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          original_submission?: Json | null
          request_number?: string
          source: Database["public"]["Enums"]["request_source"]
          status?: Database["public"]["Enums"]["service_request_status"]
          updated_at?: string
          vehicle_id?: string | null
        }
        Update: {
          admin_notes?: string | null
          client_id?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          original_submission?: Json | null
          request_number?: string
          source?: Database["public"]["Enums"]["request_source"]
          status?: Database["public"]["Enums"]["service_request_status"]
          updated_at?: string
          vehicle_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "service_requests_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "admin_clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_requests_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "client_portal_clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_requests_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_requests_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_requests_vehicle_id_fkey"
            columns: ["vehicle_id"]
            isOneToOne: false
            referencedRelation: "vehicles"
            referencedColumns: ["id"]
          },
        ]
      }
      service_work_items: {
        Row: {
          approval_note: string | null
          approval_status: Database["public"]["Enums"]["additional_work_approval_status"]
          approved_value: number | null
          approximate_value: number | null
          created_at: string
          decision_at: string | null
          decision_by_profile_id: string | null
          description: string | null
          final_value: number | null
          id: string
          name: string
          quantity: number
          quotation_item_id: string | null
          service_job_id: string
          source: Database["public"]["Enums"]["work_item_source"]
          status: Database["public"]["Enums"]["work_item_status"]
          updated_at: string
        }
        Insert: {
          approval_note?: string | null
          approval_status?: Database["public"]["Enums"]["additional_work_approval_status"]
          approved_value?: number | null
          approximate_value?: number | null
          created_at?: string
          decision_at?: string | null
          decision_by_profile_id?: string | null
          description?: string | null
          final_value?: number | null
          id?: string
          name: string
          quantity?: number
          quotation_item_id?: string | null
          service_job_id: string
          source: Database["public"]["Enums"]["work_item_source"]
          status?: Database["public"]["Enums"]["work_item_status"]
          updated_at?: string
        }
        Update: {
          approval_note?: string | null
          approval_status?: Database["public"]["Enums"]["additional_work_approval_status"]
          approved_value?: number | null
          approximate_value?: number | null
          created_at?: string
          decision_at?: string | null
          decision_by_profile_id?: string | null
          description?: string | null
          final_value?: number | null
          id?: string
          name?: string
          quantity?: number
          quotation_item_id?: string | null
          service_job_id?: string
          source?: Database["public"]["Enums"]["work_item_source"]
          status?: Database["public"]["Enums"]["work_item_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "service_work_items_decision_by_profile_id_fkey"
            columns: ["decision_by_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_work_items_quotation_item_id_fkey"
            columns: ["quotation_item_id"]
            isOneToOne: false
            referencedRelation: "quotation_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_work_items_service_job_id_fkey"
            columns: ["service_job_id"]
            isOneToOne: false
            referencedRelation: "service_jobs"
            referencedColumns: ["id"]
          },
        ]
      }
      vehicle_correction_requests: {
        Row: {
          admin_response: string | null
          client_id: string
          created_at: string
          id: string
          message: string
          profile_id: string
          requested_changes: Json | null
          responded_at: string | null
          responded_by: string | null
          status: Database["public"]["Enums"]["change_request_status"]
          vehicle_id: string
        }
        Insert: {
          admin_response?: string | null
          client_id: string
          created_at?: string
          id?: string
          message: string
          profile_id: string
          requested_changes?: Json | null
          responded_at?: string | null
          responded_by?: string | null
          status?: Database["public"]["Enums"]["change_request_status"]
          vehicle_id: string
        }
        Update: {
          admin_response?: string | null
          client_id?: string
          created_at?: string
          id?: string
          message?: string
          profile_id?: string
          requested_changes?: Json | null
          responded_at?: string | null
          responded_by?: string | null
          status?: Database["public"]["Enums"]["change_request_status"]
          vehicle_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "vehicle_correction_requests_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "admin_clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "vehicle_correction_requests_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "client_portal_clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "vehicle_correction_requests_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "vehicle_correction_requests_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "vehicle_correction_requests_responded_by_fkey"
            columns: ["responded_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "vehicle_correction_requests_vehicle_id_fkey"
            columns: ["vehicle_id"]
            isOneToOne: false
            referencedRelation: "vehicles"
            referencedColumns: ["id"]
          },
        ]
      }
      vehicles: {
        Row: {
          chassis_number: string | null
          client_id: string
          created_at: string
          id: string
          make: string
          manufacturing_year: number | null
          model: string
          registration_number: string | null
          updated_at: string
        }
        Insert: {
          chassis_number?: string | null
          client_id: string
          created_at?: string
          id?: string
          make: string
          manufacturing_year?: number | null
          model: string
          registration_number?: string | null
          updated_at?: string
        }
        Update: {
          chassis_number?: string | null
          client_id?: string
          created_at?: string
          id?: string
          make?: string
          manufacturing_year?: number | null
          model?: string
          registration_number?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "vehicles_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "admin_clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "vehicles_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "client_portal_clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "vehicles_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      admin_clients: {
        Row: {
          address: string | null
          city: string | null
          created_at: string | null
          email: string | null
          full_name: string | null
          id: string | null
          is_active: boolean | null
          notes: string | null
          phone: string | null
          pincode: string | null
          state: string | null
          updated_at: string | null
        }
        Insert: {
          address?: string | null
          city?: string | null
          created_at?: string | null
          email?: string | null
          full_name?: string | null
          id?: string | null
          is_active?: boolean | null
          notes?: string | null
          phone?: string | null
          pincode?: string | null
          state?: string | null
          updated_at?: string | null
        }
        Update: {
          address?: string | null
          city?: string | null
          created_at?: string | null
          email?: string | null
          full_name?: string | null
          id?: string | null
          is_active?: boolean | null
          notes?: string | null
          phone?: string | null
          pincode?: string | null
          state?: string | null
          updated_at?: string | null
        }
        Relationships: []
      }
      admin_service_requests: {
        Row: {
          admin_notes: string | null
          client_id: string | null
          created_at: string | null
          created_by: string | null
          id: string | null
          original_submission: Json | null
          request_number: string | null
          source: Database["public"]["Enums"]["request_source"] | null
          status: Database["public"]["Enums"]["service_request_status"] | null
          updated_at: string | null
          vehicle_id: string | null
        }
        Insert: {
          admin_notes?: string | null
          client_id?: string | null
          created_at?: string | null
          created_by?: string | null
          id?: string | null
          original_submission?: Json | null
          request_number?: string | null
          source?: Database["public"]["Enums"]["request_source"] | null
          status?: Database["public"]["Enums"]["service_request_status"] | null
          updated_at?: string | null
          vehicle_id?: string | null
        }
        Update: {
          admin_notes?: string | null
          client_id?: string | null
          created_at?: string | null
          created_by?: string | null
          id?: string | null
          original_submission?: Json | null
          request_number?: string | null
          source?: Database["public"]["Enums"]["request_source"] | null
          status?: Database["public"]["Enums"]["service_request_status"] | null
          updated_at?: string | null
          vehicle_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "service_requests_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "admin_clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_requests_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "client_portal_clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_requests_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_requests_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_requests_vehicle_id_fkey"
            columns: ["vehicle_id"]
            isOneToOne: false
            referencedRelation: "vehicles"
            referencedColumns: ["id"]
          },
        ]
      }
      client_portal_clients: {
        Row: {
          address: string | null
          city: string | null
          created_at: string | null
          email: string | null
          full_name: string | null
          id: string | null
          is_active: boolean | null
          phone: string | null
          pincode: string | null
          state: string | null
          updated_at: string | null
        }
        Insert: {
          address?: string | null
          city?: string | null
          created_at?: string | null
          email?: string | null
          full_name?: string | null
          id?: string | null
          is_active?: boolean | null
          phone?: string | null
          pincode?: string | null
          state?: string | null
          updated_at?: string | null
        }
        Update: {
          address?: string | null
          city?: string | null
          created_at?: string | null
          email?: string | null
          full_name?: string | null
          id?: string | null
          is_active?: boolean | null
          phone?: string | null
          pincode?: string | null
          state?: string | null
          updated_at?: string | null
        }
        Relationships: []
      }
      client_portal_service_requests: {
        Row: {
          client_id: string | null
          created_at: string | null
          created_by: string | null
          id: string | null
          original_submission: Json | null
          request_number: string | null
          source: Database["public"]["Enums"]["request_source"] | null
          status: Database["public"]["Enums"]["service_request_status"] | null
          updated_at: string | null
          vehicle_id: string | null
        }
        Insert: {
          client_id?: string | null
          created_at?: string | null
          created_by?: string | null
          id?: string | null
          original_submission?: Json | null
          request_number?: string | null
          source?: Database["public"]["Enums"]["request_source"] | null
          status?: Database["public"]["Enums"]["service_request_status"] | null
          updated_at?: string | null
          vehicle_id?: string | null
        }
        Update: {
          client_id?: string | null
          created_at?: string | null
          created_by?: string | null
          id?: string | null
          original_submission?: Json | null
          request_number?: string | null
          source?: Database["public"]["Enums"]["request_source"] | null
          status?: Database["public"]["Enums"]["service_request_status"] | null
          updated_at?: string | null
          vehicle_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "service_requests_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "admin_clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_requests_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "client_portal_clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_requests_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_requests_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_requests_vehicle_id_fkey"
            columns: ["vehicle_id"]
            isOneToOne: false
            referencedRelation: "vehicles"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      admin_add_additional_work: {
        Args: {
          p_approximate_value?: number
          p_description?: string
          p_final_value: number
          p_name: string
          p_quantity: number
          p_service_job_id: string
        }
        Returns: Json
      }
      admin_cancel_service_request: {
        Args: { p_reason?: string; p_service_request_id: string }
        Returns: Json
      }
      admin_cancel_service_work_item: {
        Args: { p_reason?: string; p_work_item_id: string }
        Returns: Json
      }
      admin_close_quotation_revision: {
        Args: {
          p_revision_id: string
          p_status?: Database["public"]["Enums"]["quotation_revision_status"]
        }
        Returns: Json
      }
      admin_create_quotation: {
        Args: {
          p_notes?: string
          p_service_request_id: string
          p_terms?: string
        }
        Returns: Json
      }
      admin_create_quotation_revision: {
        Args: { p_quotation_id: string }
        Returns: Json
      }
      admin_create_service_job: {
        Args: { p_quotation_revision_id: string; p_scheduled_at?: string }
        Returns: Json
      }
      admin_get_client_notes: { Args: { p_client_id: string }; Returns: string }
      admin_get_service_request_notes: {
        Args: { p_service_request_id: string }
        Returns: string
      }
      admin_link_service_request: {
        Args: {
          p_client_id: string
          p_service_request_id: string
          p_vehicle_id: string
        }
        Returns: Json
      }
      admin_respond_quotation_change_request: {
        Args: {
          p_change_request_id: string
          p_response?: string
          p_status: Database["public"]["Enums"]["change_request_status"]
        }
        Returns: Json
      }
      admin_respond_vehicle_correction: {
        Args: {
          p_request_id: string
          p_response?: string
          p_status: Database["public"]["Enums"]["change_request_status"]
        }
        Returns: Json
      }
      admin_send_quotation_revision: {
        Args: { p_revision_id: string }
        Returns: Json
      }
      admin_set_client_notes: {
        Args: { p_client_id: string; p_notes: string }
        Returns: undefined
      }
      admin_set_service_request_notes: {
        Args: { p_admin_notes: string; p_service_request_id: string }
        Returns: undefined
      }
      admin_update_service_job_status: {
        Args: {
          p_service_job_id: string
          p_status: Database["public"]["Enums"]["service_job_status"]
        }
        Returns: Json
      }
      client_accept_quotation_revision: {
        Args: {
          p_consent_given: boolean
          p_consent_text: string
          p_revision_id: string
        }
        Returns: Json
      }
      client_decide_additional_work: {
        Args: {
          p_approve: boolean
          p_expected_final_value: number
          p_note?: string
          p_work_item_id: string
        }
        Returns: Json
      }
      client_mark_quotation_viewed: {
        Args: { p_revision_id: string }
        Returns: Json
      }
      client_reject_quotation_revision: {
        Args: { p_reason?: string; p_revision_id: string }
        Returns: Json
      }
      client_request_quotation_change: {
        Args: { p_message: string; p_revision_id: string }
        Returns: Json
      }
      client_request_vehicle_correction: {
        Args: {
          p_message: string
          p_requested_changes?: Json
          p_vehicle_id: string
        }
        Returns: Json
      }
      client_sign_quotation_revision: {
        Args: { p_revision_id: string; p_signature_path: string }
        Returns: Json
      }
    }
    Enums: {
      additional_work_approval_status:
        | "NOT_REQUIRED"
        | "PENDING"
        | "APPROVED"
        | "REJECTED"
      change_request_status:
        | "PENDING"
        | "ACCEPTED"
        | "PARTIALLY_ACCEPTED"
        | "REJECTED"
        | "CANCELLED"
      document_type:
        | "QUOTATION_PDF"
        | "SIGNED_QUOTATION_PDF"
        | "SERVICE_REPORT"
        | "INVOICE"
        | "RECEIPT"
      email_delivery_status: "QUEUED" | "SENT" | "FAILED"
      notification_type:
        | "NEW_SERVICE_REQUEST"
        | "QUOTATION_SENT"
        | "QUOTATION_REVISED"
        | "QUOTATION_CHANGE_REQUESTED"
        | "QUOTATION_ACCEPTED"
        | "QUOTATION_SIGNED"
        | "ADDITIONAL_WORK_REQUESTED"
        | "ADDITIONAL_WORK_APPROVED"
        | "ADDITIONAL_WORK_REJECTED"
        | "SERVICE_STATUS_UPDATED"
        | "SERVICE_JOB_COMPLETED"
        | "QUOTATION_REJECTED"
        | "QUOTATION_CHANGE_RESPONDED"
        | "VEHICLE_CORRECTION_REQUESTED"
        | "VEHICLE_CORRECTION_RESPONDED"
      quotation_revision_status:
        | "DRAFT"
        | "SENT"
        | "VIEWED"
        | "CHANGE_REQUESTED"
        | "ACCEPTED"
        | "REJECTED"
        | "EXPIRED"
        | "CANCELLED"
        | "SUPERSEDED"
      request_source: "WEBSITE" | "PHONE"
      service_job_status:
        | "SCHEDULED"
        | "VEHICLE_RECEIVED"
        | "INSPECTION"
        | "WORK_IN_PROGRESS"
        | "QUALITY_CHECK"
        | "READY_FOR_DELIVERY"
        | "COMPLETED"
        | "CANCELLED"
      service_request_status:
        | "NEW"
        | "UNDER_REVIEW"
        | "QUOTATION_CREATED"
        | "QUOTATION_SENT"
        | "APPROVED"
        | "CONVERTED_TO_JOB"
        | "CANCELLED"
      signature_method: "DRAWN"
      user_role: "ADMIN" | "CLIENT"
      work_item_source: "QUOTATION" | "ADDITIONAL"
      work_item_status:
        | "PENDING"
        | "IN_PROGRESS"
        | "COMPLETED"
        | "ON_HOLD"
        | "CANCELLED"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      additional_work_approval_status: [
        "NOT_REQUIRED",
        "PENDING",
        "APPROVED",
        "REJECTED",
      ],
      change_request_status: [
        "PENDING",
        "ACCEPTED",
        "PARTIALLY_ACCEPTED",
        "REJECTED",
        "CANCELLED",
      ],
      document_type: [
        "QUOTATION_PDF",
        "SIGNED_QUOTATION_PDF",
        "SERVICE_REPORT",
        "INVOICE",
        "RECEIPT",
      ],
      email_delivery_status: ["QUEUED", "SENT", "FAILED"],
      notification_type: [
        "NEW_SERVICE_REQUEST",
        "QUOTATION_SENT",
        "QUOTATION_REVISED",
        "QUOTATION_CHANGE_REQUESTED",
        "QUOTATION_ACCEPTED",
        "QUOTATION_SIGNED",
        "ADDITIONAL_WORK_REQUESTED",
        "ADDITIONAL_WORK_APPROVED",
        "ADDITIONAL_WORK_REJECTED",
        "SERVICE_STATUS_UPDATED",
        "SERVICE_JOB_COMPLETED",
        "QUOTATION_REJECTED",
        "QUOTATION_CHANGE_RESPONDED",
        "VEHICLE_CORRECTION_REQUESTED",
        "VEHICLE_CORRECTION_RESPONDED",
      ],
      quotation_revision_status: [
        "DRAFT",
        "SENT",
        "VIEWED",
        "CHANGE_REQUESTED",
        "ACCEPTED",
        "REJECTED",
        "EXPIRED",
        "CANCELLED",
        "SUPERSEDED",
      ],
      request_source: ["WEBSITE", "PHONE"],
      service_job_status: [
        "SCHEDULED",
        "VEHICLE_RECEIVED",
        "INSPECTION",
        "WORK_IN_PROGRESS",
        "QUALITY_CHECK",
        "READY_FOR_DELIVERY",
        "COMPLETED",
        "CANCELLED",
      ],
      service_request_status: [
        "NEW",
        "UNDER_REVIEW",
        "QUOTATION_CREATED",
        "QUOTATION_SENT",
        "APPROVED",
        "CONVERTED_TO_JOB",
        "CANCELLED",
      ],
      signature_method: ["DRAWN"],
      user_role: ["ADMIN", "CLIENT"],
      work_item_source: ["QUOTATION", "ADDITIONAL"],
      work_item_status: [
        "PENDING",
        "IN_PROGRESS",
        "COMPLETED",
        "ON_HOLD",
        "CANCELLED",
      ],
    },
  },
} as const
