
BEGIN;
CREATE TABLE public.sai_system_settings (
 category text NOT NULL,
 setting_key text NOT NULL,
 value_text text NOT NULL DEFAULT '',
 updated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(category,setting_key),
 CONSTRAINT sai_settings_value_limit CHECK (length(value_text)<=2000),
 CONSTRAINT sai_settings_allowed_keys CHECK (
  (category='general' AND setting_key IN ('college_name','website_url','contact_email','contact_phone','address'))
  OR (category='sessions' AND setting_key IN ('default_session_id','registration_open'))
  OR (category='notifications' AND setting_key IN ('push_enabled','digest_enabled','quiet_hours'))
  OR (category='sms' AND setting_key IN ('enabled','provider_name','sender_name'))
  OR (category='whatsapp' AND setting_key IN ('enabled','business_number','template_namespace'))
  OR (category='email' AND setting_key IN ('enabled','sender_address','sender_name'))
  OR (category='payments' AND setting_key IN ('default_currency','invoice_prefix','enabled_methods'))
  OR (category='printing' AND setting_key IN ('paper_size','header_text','footer_text'))
  OR (category='cms' AND setting_key IN ('site_title','default_locale','public_notice'))
  OR (category='backups' AND setting_key IN ('retention_days','alert_email'))
  OR (category='languages' AND setting_key IN ('default_locale','enabled_locales','timezone'))
  OR (category='currencies' AND setting_key IN ('base_currency','enabled_currencies'))
  OR (category='extensions' AND setting_key IN ('enabled_module_ids','enabled_plugin_ids'))
  OR (category='custom_fields' AND setting_key IN ('student_form_schema','admissions_form_schema'))
  OR (category='verification' AND setting_key IN ('certificate_verification_enabled','guardian_check_required'))
  OR (category='updates' AND setting_key IN ('release_channel','maintenance_notice'))
 ),
 CONSTRAINT sai_settings_boolean_values CHECK (
  setting_key NOT IN ('enabled','push_enabled','digest_enabled','registration_open','certificate_verification_enabled','guardian_check_required')
  OR value_text IN ('true','false')
 )
);
COMMENT ON TABLE public.sai_system_settings IS 'Non-secret, allowlisted site/app settings only; never store credentials, tokens, SMTP passwords or payment secrets.';
CREATE TABLE public.sai_system_settings_audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 category text NOT NULL,
 setting_key text NOT NULL,
 action text NOT NULL CHECK (action IN ('INSERT','UPDATE','DELETE')),
 actor_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 happened_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX sai_settings_audit_time_idx ON public.sai_system_settings_audit(happened_at DESC);
CREATE FUNCTION private.sai_system_settings_stamp()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
BEGIN
 NEW.updated_by:=(SELECT auth.uid());
 NEW.updated_at:=now();
 RETURN NEW;
END $$;
CREATE TRIGGER sai_system_settings_stamp_trigger BEFORE INSERT OR UPDATE ON public.sai_system_settings
FOR EACH ROW EXECUTE FUNCTION private.sai_system_settings_stamp();
CREATE FUNCTION private.sai_system_settings_log()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF TG_OP='DELETE' THEN
  INSERT INTO public.sai_system_settings_audit(category,setting_key,action,actor_user_id)
   VALUES (OLD.category,OLD.setting_key,TG_OP,(SELECT auth.uid()));
  RETURN OLD;
 END IF;
 INSERT INTO public.sai_system_settings_audit(category,setting_key,action,actor_user_id)
  VALUES (NEW.category,NEW.setting_key,TG_OP,(SELECT auth.uid()));
 RETURN NEW;
END $$;
CREATE TRIGGER sai_system_settings_audit_trigger AFTER INSERT OR UPDATE OR DELETE ON public.sai_system_settings
FOR EACH ROW EXECUTE FUNCTION private.sai_system_settings_log();
REVOKE ALL ON FUNCTION private.sai_system_settings_stamp(),private.sai_system_settings_log() FROM PUBLIC,anon,authenticated;
ALTER TABLE public.sai_system_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sai_system_settings_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sai_system_settings,public.sai_system_settings_audit FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE ON public.sai_system_settings TO authenticated;
GRANT SELECT ON public.sai_system_settings_audit TO authenticated;
CREATE POLICY sai_settings_read ON public.sai_system_settings FOR SELECT TO authenticated
 USING (private.sai_security_has_role('super_admin'::public.app_role)
        OR (private.sai_security_has_role('admin'::public.app_role)
            AND category NOT IN ('backups','extensions','verification','updates')));
CREATE POLICY sai_settings_insert ON public.sai_system_settings FOR INSERT TO authenticated
 WITH CHECK (private.sai_security_has_role('super_admin'::public.app_role));
CREATE POLICY sai_settings_update ON public.sai_system_settings FOR UPDATE TO authenticated
 USING (private.sai_security_has_role('super_admin'::public.app_role))
 WITH CHECK (private.sai_security_has_role('super_admin'::public.app_role));
CREATE POLICY sai_settings_audit_read ON public.sai_system_settings_audit FOR SELECT TO authenticated
 USING (private.sai_security_has_role('super_admin'::public.app_role));
COMMIT;;
