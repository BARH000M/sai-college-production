
CREATE FUNCTION public.sai_unified_module_stamp() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF TG_OP='INSERT' THEN NEW.created_by=(SELECT auth.uid()); NEW.created_at=now();
 ELSE NEW.created_by=OLD.created_by; NEW.created_at=OLD.created_at; END IF;
 NEW.updated_at=now(); RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.sai_unified_module_stamp() FROM public,anon,authenticated;
CREATE FUNCTION public.sai_unified_module_audit() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE rid uuid; bid uuid;
BEGIN
 IF TG_OP='DELETE' THEN rid=OLD.id; bid=OLD.branch_id; ELSE rid=NEW.id; bid=NEW.branch_id; END IF;
 INSERT INTO public.audit_logs(actor_user_id,action,entity_type,entity_id,metadata)
 VALUES((SELECT auth.uid()),TG_OP,TG_TABLE_NAME,rid,jsonb_build_object('branch_id',bid));
 IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END $$;
REVOKE ALL ON FUNCTION public.sai_unified_module_audit() FROM public,anon,authenticated;
CREATE FUNCTION public.sai_unified_module_student_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NEW.student_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.students s WHERE s.id=NEW.student_id AND s.branch_id=NEW.branch_id)
 THEN RAISE EXCEPTION 'Student and record must belong to same branch' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.sai_unified_module_student_guard() FROM public,anon,authenticated;

CREATE TABLE public.sai_download_resources(
 id uuid primary key default gen_random_uuid(),
 branch_id uuid not null references public.branches(id),
 title text not null check(length(btrim(title)) between 1 and 200),
 description text,
 category text, storage_path text, is_published boolean not null default false,
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
CREATE INDEX sai_download_resources_branch_idx ON public.sai_download_resources(branch_id,created_at DESC);
ALTER TABLE public.sai_download_resources ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sai_download_resources FROM public,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.sai_download_resources TO authenticated;
CREATE POLICY sai_download_resources_read ON public.sai_download_resources FOR SELECT TO authenticated USING (private.sai_security_has_role('super_admin'::public.app_role) OR ((private.sai_security_branch_member(sai_download_resources.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('librarian'::public.app_role) OR private.sai_security_has_role('content_editor'::public.app_role))) OR (sai_download_resources.is_published AND (private.sai_security_branch_member(sai_download_resources.branch_id) OR EXISTS(SELECT 1 FROM public.students s WHERE s.branch_id=sai_download_resources.branch_id AND s.user_id=(SELECT auth.uid())) OR EXISTS(SELECT 1 FROM public.parent_student_links l JOIN public.students s ON s.id=l.student_id WHERE l.parent_user_id=(SELECT auth.uid()) AND l.verified_at IS NOT NULL AND s.branch_id=sai_download_resources.branch_id)))));
CREATE POLICY sai_download_resources_insert ON public.sai_download_resources FOR INSERT TO authenticated WITH CHECK (private.sai_security_has_role('super_admin'::public.app_role) OR (private.sai_security_branch_member(sai_download_resources.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('librarian'::public.app_role) OR private.sai_security_has_role('content_editor'::public.app_role))));
CREATE POLICY sai_download_resources_update ON public.sai_download_resources FOR UPDATE TO authenticated USING (private.sai_security_has_role('super_admin'::public.app_role) OR (private.sai_security_branch_member(sai_download_resources.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('librarian'::public.app_role) OR private.sai_security_has_role('content_editor'::public.app_role)))) WITH CHECK (private.sai_security_has_role('super_admin'::public.app_role) OR (private.sai_security_branch_member(sai_download_resources.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('librarian'::public.app_role) OR private.sai_security_has_role('content_editor'::public.app_role))));
CREATE POLICY sai_download_resources_delete ON public.sai_download_resources FOR DELETE TO authenticated USING (private.sai_security_has_role('super_admin'::public.app_role) OR (private.sai_security_branch_member(sai_download_resources.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('librarian'::public.app_role) OR private.sai_security_has_role('content_editor'::public.app_role))));

CREATE TRIGGER sai_download_resources_stamp BEFORE INSERT OR UPDATE ON public.sai_download_resources FOR EACH ROW EXECUTE FUNCTION public.sai_unified_module_stamp();
CREATE TRIGGER sai_download_resources_audit AFTER INSERT OR UPDATE OR DELETE ON public.sai_download_resources FOR EACH ROW EXECUTE FUNCTION public.sai_unified_module_audit();


CREATE TABLE public.sai_inventory_items(
 id uuid primary key default gen_random_uuid(),
 branch_id uuid not null references public.branches(id),
 title text not null check(length(btrim(title)) between 1 and 200),
 description text,
 sku text, quantity integer not null default 0 check(quantity >= 0), warehouse text,
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
CREATE INDEX sai_inventory_items_branch_idx ON public.sai_inventory_items(branch_id,created_at DESC);
ALTER TABLE public.sai_inventory_items ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sai_inventory_items FROM public,anon,authenticated;
GRANT SELECT,INSERT,UPDATE ON public.sai_inventory_items TO authenticated;
CREATE POLICY sai_inventory_items_read ON public.sai_inventory_items FOR SELECT TO authenticated USING (private.sai_security_has_role('super_admin'::public.app_role) OR (private.sai_security_branch_member(sai_inventory_items.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('accountant'::public.app_role))));
CREATE POLICY sai_inventory_items_insert ON public.sai_inventory_items FOR INSERT TO authenticated WITH CHECK (private.sai_security_has_role('super_admin'::public.app_role) OR (private.sai_security_branch_member(sai_inventory_items.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('accountant'::public.app_role))));
CREATE POLICY sai_inventory_items_update ON public.sai_inventory_items FOR UPDATE TO authenticated USING (private.sai_security_has_role('super_admin'::public.app_role) OR (private.sai_security_branch_member(sai_inventory_items.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('accountant'::public.app_role)))) WITH CHECK (private.sai_security_has_role('super_admin'::public.app_role) OR (private.sai_security_branch_member(sai_inventory_items.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('accountant'::public.app_role))));


CREATE TRIGGER sai_inventory_items_stamp BEFORE INSERT OR UPDATE ON public.sai_inventory_items FOR EACH ROW EXECUTE FUNCTION public.sai_unified_module_stamp();
CREATE TRIGGER sai_inventory_items_audit AFTER INSERT OR UPDATE OR DELETE ON public.sai_inventory_items FOR EACH ROW EXECUTE FUNCTION public.sai_unified_module_audit();


CREATE TABLE public.sai_transport_routes(
 id uuid primary key default gen_random_uuid(),
 branch_id uuid not null references public.branches(id),
 title text not null check(length(btrim(title)) between 1 and 200),
 description text,
 vehicle text, capacity integer not null default 0 check(capacity >= 0), driver_name text,
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
CREATE INDEX sai_transport_routes_branch_idx ON public.sai_transport_routes(branch_id,created_at DESC);
ALTER TABLE public.sai_transport_routes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sai_transport_routes FROM public,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.sai_transport_routes TO authenticated;
CREATE POLICY sai_transport_routes_read ON public.sai_transport_routes FOR SELECT TO authenticated USING (private.sai_security_has_role('super_admin'::public.app_role) OR ((private.sai_security_branch_member(sai_transport_routes.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('receptionist'::public.app_role))) OR (private.sai_security_branch_member(sai_transport_routes.branch_id) OR EXISTS(SELECT 1 FROM public.students s WHERE s.branch_id=sai_transport_routes.branch_id AND s.user_id=(SELECT auth.uid())) OR EXISTS(SELECT 1 FROM public.parent_student_links l JOIN public.students s ON s.id=l.student_id WHERE l.parent_user_id=(SELECT auth.uid()) AND l.verified_at IS NOT NULL AND s.branch_id=sai_transport_routes.branch_id))));
CREATE POLICY sai_transport_routes_insert ON public.sai_transport_routes FOR INSERT TO authenticated WITH CHECK (private.sai_security_has_role('super_admin'::public.app_role) OR (private.sai_security_branch_member(sai_transport_routes.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('receptionist'::public.app_role))));
CREATE POLICY sai_transport_routes_update ON public.sai_transport_routes FOR UPDATE TO authenticated USING (private.sai_security_has_role('super_admin'::public.app_role) OR (private.sai_security_branch_member(sai_transport_routes.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('receptionist'::public.app_role)))) WITH CHECK (private.sai_security_has_role('super_admin'::public.app_role) OR (private.sai_security_branch_member(sai_transport_routes.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('receptionist'::public.app_role))));
CREATE POLICY sai_transport_routes_delete ON public.sai_transport_routes FOR DELETE TO authenticated USING (private.sai_security_has_role('super_admin'::public.app_role) OR (private.sai_security_branch_member(sai_transport_routes.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('receptionist'::public.app_role))));

CREATE TRIGGER sai_transport_routes_stamp BEFORE INSERT OR UPDATE ON public.sai_transport_routes FOR EACH ROW EXECUTE FUNCTION public.sai_unified_module_stamp();
CREATE TRIGGER sai_transport_routes_audit AFTER INSERT OR UPDATE OR DELETE ON public.sai_transport_routes FOR EACH ROW EXECUTE FUNCTION public.sai_unified_module_audit();


CREATE TABLE public.sai_student_portfolios(
 id uuid primary key default gen_random_uuid(),
 branch_id uuid not null references public.branches(id),
 title text not null check(length(btrim(title)) between 1 and 200),
 description text,
 student_id uuid references public.students(id), category text,
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
CREATE INDEX sai_student_portfolios_branch_idx ON public.sai_student_portfolios(branch_id,created_at DESC);
ALTER TABLE public.sai_student_portfolios ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sai_student_portfolios FROM public,anon,authenticated;
GRANT SELECT,INSERT,UPDATE ON public.sai_student_portfolios TO authenticated;
CREATE POLICY sai_student_portfolios_read ON public.sai_student_portfolios FOR SELECT TO authenticated USING (private.sai_security_has_role('super_admin'::public.app_role) OR ((private.sai_security_branch_member(sai_student_portfolios.branch_id) AND (private.sai_security_has_role('admin'::public.app_role))) OR (private.sai_security_has_role('teacher'::public.app_role) AND EXISTS(SELECT 1 FROM public.students s JOIN public.classes c ON c.id=s.class_id WHERE s.id=sai_student_portfolios.student_id AND s.branch_id=sai_student_portfolios.branch_id AND c.branch_id=sai_student_portfolios.branch_id AND c.teacher_id=(SELECT auth.uid()))) OR (sai_student_portfolios.student_id IS NOT NULL AND (EXISTS(SELECT 1 FROM public.students s WHERE s.id=sai_student_portfolios.student_id AND s.user_id=(SELECT auth.uid())) OR EXISTS(SELECT 1 FROM public.parent_student_links l WHERE l.student_id=sai_student_portfolios.student_id AND l.parent_user_id=(SELECT auth.uid()) AND l.verified_at IS NOT NULL)))));
CREATE POLICY sai_student_portfolios_insert ON public.sai_student_portfolios FOR INSERT TO authenticated WITH CHECK (private.sai_security_has_role('super_admin'::public.app_role) OR ((private.sai_security_branch_member(sai_student_portfolios.branch_id) AND (private.sai_security_has_role('admin'::public.app_role))) OR (private.sai_security_has_role('teacher'::public.app_role) AND EXISTS(SELECT 1 FROM public.students s JOIN public.classes c ON c.id=s.class_id WHERE s.id=sai_student_portfolios.student_id AND s.branch_id=sai_student_portfolios.branch_id AND c.branch_id=sai_student_portfolios.branch_id AND c.teacher_id=(SELECT auth.uid())))));
CREATE POLICY sai_student_portfolios_update ON public.sai_student_portfolios FOR UPDATE TO authenticated USING (private.sai_security_has_role('super_admin'::public.app_role) OR ((private.sai_security_branch_member(sai_student_portfolios.branch_id) AND (private.sai_security_has_role('admin'::public.app_role))) OR (private.sai_security_has_role('teacher'::public.app_role) AND EXISTS(SELECT 1 FROM public.students s JOIN public.classes c ON c.id=s.class_id WHERE s.id=sai_student_portfolios.student_id AND s.branch_id=sai_student_portfolios.branch_id AND c.branch_id=sai_student_portfolios.branch_id AND c.teacher_id=(SELECT auth.uid()))))) WITH CHECK (private.sai_security_has_role('super_admin'::public.app_role) OR ((private.sai_security_branch_member(sai_student_portfolios.branch_id) AND (private.sai_security_has_role('admin'::public.app_role))) OR (private.sai_security_has_role('teacher'::public.app_role) AND EXISTS(SELECT 1 FROM public.students s JOIN public.classes c ON c.id=s.class_id WHERE s.id=sai_student_portfolios.student_id AND s.branch_id=sai_student_portfolios.branch_id AND c.branch_id=sai_student_portfolios.branch_id AND c.teacher_id=(SELECT auth.uid())))));


CREATE TRIGGER sai_student_portfolios_stamp BEFORE INSERT OR UPDATE ON public.sai_student_portfolios FOR EACH ROW EXECUTE FUNCTION public.sai_unified_module_stamp();
CREATE TRIGGER sai_student_portfolios_audit AFTER INSERT OR UPDATE OR DELETE ON public.sai_student_portfolios FOR EACH ROW EXECUTE FUNCTION public.sai_unified_module_audit();
CREATE TRIGGER sai_student_portfolios_student_guard BEFORE INSERT OR UPDATE OF branch_id,student_id ON public.sai_student_portfolios FOR EACH ROW EXECUTE FUNCTION public.sai_unified_module_student_guard();

CREATE TABLE public.sai_housing_rooms(
 id uuid primary key default gen_random_uuid(),
 branch_id uuid not null references public.branches(id),
 title text not null check(length(btrim(title)) between 1 and 200),
 description text,
 building text, capacity integer not null default 0 check(capacity >= 0),
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
CREATE INDEX sai_housing_rooms_branch_idx ON public.sai_housing_rooms(branch_id,created_at DESC);
ALTER TABLE public.sai_housing_rooms ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sai_housing_rooms FROM public,anon,authenticated;
GRANT SELECT,INSERT,UPDATE ON public.sai_housing_rooms TO authenticated;
CREATE POLICY sai_housing_rooms_read ON public.sai_housing_rooms FOR SELECT TO authenticated USING (private.sai_security_has_role('super_admin'::public.app_role) OR ((private.sai_security_branch_member(sai_housing_rooms.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('receptionist'::public.app_role))) OR (private.sai_security_branch_member(sai_housing_rooms.branch_id) OR EXISTS(SELECT 1 FROM public.students s WHERE s.branch_id=sai_housing_rooms.branch_id AND s.user_id=(SELECT auth.uid())) OR EXISTS(SELECT 1 FROM public.parent_student_links l JOIN public.students s ON s.id=l.student_id WHERE l.parent_user_id=(SELECT auth.uid()) AND l.verified_at IS NOT NULL AND s.branch_id=sai_housing_rooms.branch_id))));
CREATE POLICY sai_housing_rooms_insert ON public.sai_housing_rooms FOR INSERT TO authenticated WITH CHECK (private.sai_security_has_role('super_admin'::public.app_role) OR (private.sai_security_branch_member(sai_housing_rooms.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('receptionist'::public.app_role))));
CREATE POLICY sai_housing_rooms_update ON public.sai_housing_rooms FOR UPDATE TO authenticated USING (private.sai_security_has_role('super_admin'::public.app_role) OR (private.sai_security_branch_member(sai_housing_rooms.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('receptionist'::public.app_role)))) WITH CHECK (private.sai_security_has_role('super_admin'::public.app_role) OR (private.sai_security_branch_member(sai_housing_rooms.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('receptionist'::public.app_role))));


CREATE TRIGGER sai_housing_rooms_stamp BEFORE INSERT OR UPDATE ON public.sai_housing_rooms FOR EACH ROW EXECUTE FUNCTION public.sai_unified_module_stamp();
CREATE TRIGGER sai_housing_rooms_audit AFTER INSERT OR UPDATE OR DELETE ON public.sai_housing_rooms FOR EACH ROW EXECUTE FUNCTION public.sai_unified_module_audit();


CREATE TABLE public.sai_certificates(
 id uuid primary key default gen_random_uuid(),
 branch_id uuid not null references public.branches(id),
 title text not null check(length(btrim(title)) between 1 and 200),
 description text,
 student_id uuid references public.students(id), serial_code text, issued_on date,
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
CREATE INDEX sai_certificates_branch_idx ON public.sai_certificates(branch_id,created_at DESC);
ALTER TABLE public.sai_certificates ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sai_certificates FROM public,anon,authenticated;
GRANT SELECT,INSERT,UPDATE ON public.sai_certificates TO authenticated;
CREATE POLICY sai_certificates_read ON public.sai_certificates FOR SELECT TO authenticated USING (private.sai_security_has_role('super_admin'::public.app_role) OR ((private.sai_security_branch_member(sai_certificates.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('receptionist'::public.app_role))) OR (sai_certificates.student_id IS NOT NULL AND (EXISTS(SELECT 1 FROM public.students s WHERE s.id=sai_certificates.student_id AND s.user_id=(SELECT auth.uid())) OR EXISTS(SELECT 1 FROM public.parent_student_links l WHERE l.student_id=sai_certificates.student_id AND l.parent_user_id=(SELECT auth.uid()) AND l.verified_at IS NOT NULL)))));
CREATE POLICY sai_certificates_insert ON public.sai_certificates FOR INSERT TO authenticated WITH CHECK (private.sai_security_has_role('super_admin'::public.app_role) OR (private.sai_security_branch_member(sai_certificates.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('receptionist'::public.app_role))));
CREATE POLICY sai_certificates_update ON public.sai_certificates FOR UPDATE TO authenticated USING (private.sai_security_has_role('super_admin'::public.app_role) OR (private.sai_security_branch_member(sai_certificates.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('receptionist'::public.app_role)))) WITH CHECK (private.sai_security_has_role('super_admin'::public.app_role) OR (private.sai_security_branch_member(sai_certificates.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('receptionist'::public.app_role))));


CREATE TRIGGER sai_certificates_stamp BEFORE INSERT OR UPDATE ON public.sai_certificates FOR EACH ROW EXECUTE FUNCTION public.sai_unified_module_stamp();
CREATE TRIGGER sai_certificates_audit AFTER INSERT OR UPDATE OR DELETE ON public.sai_certificates FOR EACH ROW EXECUTE FUNCTION public.sai_unified_module_audit();
CREATE TRIGGER sai_certificates_student_guard BEFORE INSERT OR UPDATE OF branch_id,student_id ON public.sai_certificates FOR EACH ROW EXECUTE FUNCTION public.sai_unified_module_student_guard();

CREATE TABLE public.sai_cms_pages(
 id uuid primary key default gen_random_uuid(),
 branch_id uuid not null references public.branches(id),
 title text not null check(length(btrim(title)) between 1 and 200),
 description text,
 slug text, body text, is_published boolean not null default false,
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
CREATE INDEX sai_cms_pages_branch_idx ON public.sai_cms_pages(branch_id,created_at DESC);
ALTER TABLE public.sai_cms_pages ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sai_cms_pages FROM public,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.sai_cms_pages TO authenticated;
CREATE POLICY sai_cms_pages_read ON public.sai_cms_pages FOR SELECT TO authenticated USING (private.sai_security_has_role('super_admin'::public.app_role) OR ((private.sai_security_branch_member(sai_cms_pages.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('content_editor'::public.app_role))) OR sai_cms_pages.is_published));
CREATE POLICY sai_cms_pages_insert ON public.sai_cms_pages FOR INSERT TO authenticated WITH CHECK (private.sai_security_has_role('super_admin'::public.app_role) OR (private.sai_security_branch_member(sai_cms_pages.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('content_editor'::public.app_role))));
CREATE POLICY sai_cms_pages_update ON public.sai_cms_pages FOR UPDATE TO authenticated USING (private.sai_security_has_role('super_admin'::public.app_role) OR (private.sai_security_branch_member(sai_cms_pages.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('content_editor'::public.app_role)))) WITH CHECK (private.sai_security_has_role('super_admin'::public.app_role) OR (private.sai_security_branch_member(sai_cms_pages.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('content_editor'::public.app_role))));
CREATE POLICY sai_cms_pages_delete ON public.sai_cms_pages FOR DELETE TO authenticated USING (private.sai_security_has_role('super_admin'::public.app_role) OR (private.sai_security_branch_member(sai_cms_pages.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('content_editor'::public.app_role))));
GRANT SELECT ON public.sai_cms_pages TO anon; CREATE POLICY sai_cms_pages_anon_read ON public.sai_cms_pages FOR SELECT TO anon USING (is_published);
CREATE TRIGGER sai_cms_pages_stamp BEFORE INSERT OR UPDATE ON public.sai_cms_pages FOR EACH ROW EXECUTE FUNCTION public.sai_unified_module_stamp();
CREATE TRIGGER sai_cms_pages_audit AFTER INSERT OR UPDATE OR DELETE ON public.sai_cms_pages FOR EACH ROW EXECUTE FUNCTION public.sai_unified_module_audit();


CREATE TABLE public.sai_alumni(
 id uuid primary key default gen_random_uuid(),
 branch_id uuid not null references public.branches(id),
 title text not null check(length(btrim(title)) between 1 and 200),
 description text,
 student_id uuid references public.students(id), graduation_year integer check(graduation_year between 1900 and 2200),
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
CREATE INDEX sai_alumni_branch_idx ON public.sai_alumni(branch_id,created_at DESC);
ALTER TABLE public.sai_alumni ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sai_alumni FROM public,anon,authenticated;
GRANT SELECT,INSERT,UPDATE ON public.sai_alumni TO authenticated;
CREATE POLICY sai_alumni_read ON public.sai_alumni FOR SELECT TO authenticated USING (private.sai_security_has_role('super_admin'::public.app_role) OR ((private.sai_security_branch_member(sai_alumni.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('receptionist'::public.app_role))) OR (sai_alumni.student_id IS NOT NULL AND (EXISTS(SELECT 1 FROM public.students s WHERE s.id=sai_alumni.student_id AND s.user_id=(SELECT auth.uid())) OR EXISTS(SELECT 1 FROM public.parent_student_links l WHERE l.student_id=sai_alumni.student_id AND l.parent_user_id=(SELECT auth.uid()) AND l.verified_at IS NOT NULL)))));
CREATE POLICY sai_alumni_insert ON public.sai_alumni FOR INSERT TO authenticated WITH CHECK (private.sai_security_has_role('super_admin'::public.app_role) OR (private.sai_security_branch_member(sai_alumni.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('receptionist'::public.app_role))));
CREATE POLICY sai_alumni_update ON public.sai_alumni FOR UPDATE TO authenticated USING (private.sai_security_has_role('super_admin'::public.app_role) OR (private.sai_security_branch_member(sai_alumni.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('receptionist'::public.app_role)))) WITH CHECK (private.sai_security_has_role('super_admin'::public.app_role) OR (private.sai_security_branch_member(sai_alumni.branch_id) AND (private.sai_security_has_role('admin'::public.app_role) OR private.sai_security_has_role('receptionist'::public.app_role))));


CREATE TRIGGER sai_alumni_stamp BEFORE INSERT OR UPDATE ON public.sai_alumni FOR EACH ROW EXECUTE FUNCTION public.sai_unified_module_stamp();
CREATE TRIGGER sai_alumni_audit AFTER INSERT OR UPDATE OR DELETE ON public.sai_alumni FOR EACH ROW EXECUTE FUNCTION public.sai_unified_module_audit();
CREATE TRIGGER sai_alumni_student_guard BEFORE INSERT OR UPDATE OF branch_id,student_id ON public.sai_alumni FOR EACH ROW EXECUTE FUNCTION public.sai_unified_module_student_guard();
CREATE UNIQUE INDEX sai_cms_pages_slug_unique_idx ON public.sai_cms_pages(branch_id,slug) WHERE slug IS NOT NULL;;
