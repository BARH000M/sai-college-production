DO $$
DECLARE table_name text;
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname='supabase_realtime') THEN
  RAISE EXCEPTION 'supabase_realtime publication is not configured';
 END IF;
 FOREACH table_name IN ARRAY ARRAY['sai_download_resources','sai_inventory_items','sai_transport_routes','sai_student_portfolios','sai_housing_rooms','sai_certificates','sai_cms_pages','sai_alumni'] LOOP
   IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename=table_name) THEN
    EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',table_name);
   END IF;
 END LOOP;
END $$;;
