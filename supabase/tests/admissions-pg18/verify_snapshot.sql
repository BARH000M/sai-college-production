DO $$
DECLARE
  v_enquiry uuid := '90000000-0000-4000-8000-000000000001';
  v_status text;
  v_event_count integer;
  v_snapshot_count integer;
  v_audit_count integer;
BEGIN
  SELECT status INTO v_status FROM public.admissions_enquiries WHERE id = v_enquiry;
  SELECT count(*), count(*) FILTER (WHERE action = 'current_status_snapshot')
    INTO v_event_count, v_snapshot_count
    FROM private.admission_status_events WHERE enquiry_id = v_enquiry;
  SELECT count(*) INTO v_audit_count FROM public.audit_logs
    WHERE entity_id = v_enquiry AND metadata->>'forged_fixture' = 'true';
  IF v_status IS DISTINCT FROM 'new' OR v_event_count <> 1 OR v_snapshot_count <> 1
     OR v_audit_count <> 1
     OR NOT EXISTS (
       SELECT 1 FROM private.admission_status_events
       WHERE enquiry_id = v_enquiry AND action = 'current_status_snapshot'
         AND status = v_status AND old_status IS NULL
     )
     OR EXISTS (
       SELECT 1 FROM private.admission_status_events
       WHERE enquiry_id = v_enquiry AND action <> 'current_status_snapshot'
     ) THEN
    RAISE EXCEPTION 'Snapshot verification failed: current %, events %, snapshots %, forged audit rows %',
      v_status, v_event_count, v_snapshot_count, v_audit_count;
  END IF;
  RAISE NOTICE 'PASS: existing enquiry snapshot only; current_status=new; events=1; forged audit row preserved but not copied';
END $$;
SELECT jsonb_pretty(jsonb_build_object(
  'enquiry_id', e.id,
  'current_status', e.status,
  'event_history', (SELECT jsonb_agg(jsonb_build_object('action', a.action, 'status', a.status, 'old_status', a.old_status)
    ORDER BY a.occurred_at, a.id) FROM private.admission_status_events a WHERE a.enquiry_id=e.id),
  'forged_audit_rows', (SELECT count(*) FROM public.audit_logs l WHERE l.entity_id=e.id AND l.metadata->>'forged_fixture'='true')
)) AS preserved_snapshot_evidence
FROM public.admissions_enquiries e WHERE e.id='90000000-0000-4000-8000-000000000001';
