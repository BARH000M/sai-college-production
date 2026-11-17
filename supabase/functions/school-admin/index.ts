import { handleManageRoles } from "../_shared/role-management-handler.ts";
import { mutationGateOpen } from "../_shared/mutation-gate.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.119.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const STAFF_ROLES = ['super_admin', 'admin', 'receptionist', 'accountant', 'librarian', 'content_editor', 'teacher'];
const MANAGER_ROLES = ['super_admin', 'admin', 'receptionist'];

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function cleanString(value: unknown, max: number): string {
  return String(value ?? '').trim().slice(0, max);
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  let body: { action?: string; payload?: Record<string, unknown> } = {};
  try {
    body = await req.json();
  } catch {
    return json({ error: 'invalid_json', message: 'Malformed request body.' }, 400);
  }

  const action = String(body?.action ?? '');
  const payload = (body?.payload ?? {}) as Record<string, unknown>;

  if (action === 'grant-role' || action === 'revoke-role') {
    const response = await handleManageRoles(new Request(req.url, {
      method: 'POST', headers: req.headers,
      body: JSON.stringify({ ...payload, action: action === 'grant-role' ? 'grant' : 'revoke' }),
    }));
    if (!response.ok) return response;
    return json({ data: { userId: payload.userId, role: payload.role, changed: true } });
  }

  const url = Deno.env.get('SUPABASE_URL') ?? '';
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const authHeader = req.headers.get('Authorization') ?? '';
  const token = authHeader.toLowerCase().startsWith('bearer ') ? authHeader.slice(7).trim() : '';
  let callerId: string | null = null;
  if (token) {
    const authClient = createClient(url, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data, error } = await authClient.auth.getUser(token);
    if (!error && data?.user) callerId = data.user.id;
  }

  const rolesOf = async (userId: string): Promise<string[]> => {
    const { data } = await admin.from('user_roles').select('role').eq('user_id', userId);
    return ((data ?? []) as { role: string }[]).map((row) => row.role);
  };

  const hasAnyRole = async (userId: string, allowed: string[]) => {
    const roles = await rolesOf(userId);
    return roles.some((role) => allowed.includes(role));
  };

  const resolveBranchId = async (): Promise<string | null> => {
    const active = await admin
      .from('branches')
      .select('id')
      .eq('is_active', true)
      .order('created_at', { ascending: true })
      .limit(1);
    if (active.data && active.data.length > 0) return (active.data[0] as { id: string }).id;
    const any = await admin.from('branches').select('id').order('created_at', { ascending: true }).limit(1);
    return ((any.data ?? [])[0] as { id: string } | undefined)?.id ?? null;
  };

  const resolveSessionId = async (): Promise<string | null> => {
    const active = await admin
      .from('academic_sessions')
      .select('id')
      .eq('is_active', true)
      .order('starts_on', { ascending: false })
      .limit(1);
    if (active.data && active.data.length > 0) return (active.data[0] as { id: string }).id;
    const any = await admin
      .from('academic_sessions')
      .select('id')
      .order('starts_on', { ascending: false })
      .limit(1);
    return ((any.data ?? [])[0] as { id: string } | undefined)?.id ?? null;
  };

  /* Public: website application becomes a real admissions record */
  if (action === 'submit-application') {
    if (!await mutationGateOpen(admin)) {
      return json({ error: 'maintenance', message: 'Admissions are temporarily unavailable.' }, 503);
    }

    const fullName = cleanString(payload.fullName, 120);
    const guardianName = cleanString(payload.guardianName, 120);
    const phone = cleanString(payload.phone, 40);
    const email = cleanString(payload.email, 160);
    const program = cleanString(payload.program, 120);
    const level = cleanString(payload.level, 60);
    const notes = cleanString(payload.notes, 1000);

    if (fullName.length < 2) {
      return json({ error: 'invalid_name', message: 'Applicant name is required.' }, 400);
    }
    if (!phone && !email) {
      return json({ error: 'missing_contact', message: 'A phone number or email is required.' }, 400);
    }
    if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return json({ error: 'invalid_email', message: 'Enter a valid email address.' }, 400);
    }

    const [branchId, sessionId] = await Promise.all([resolveBranchId(), resolveSessionId()]);
    if (!branchId || !sessionId) {
      return json({ error: 'college_not_configured', message: 'Admissions are not open yet.' }, 409);
    }

    const adminRole = await admin.from('user_roles').select('user_id').eq('role', 'super_admin').limit(1);
    let createdBy = ((adminRole.data ?? [])[0] as { user_id: string } | undefined)?.user_id ?? null;
    if (!createdBy) {
      const profile = await admin.from('profiles').select('id').limit(1);
      createdBy = ((profile.data ?? [])[0] as { id: string } | undefined)?.id ?? null;
    }
    if (!createdBy) {
      return json({ error: 'college_not_configured', message: 'Admissions desk is not set up yet.' }, 409);
    }

    const year = new Date().getUTCFullYear();
    const prefix = `SAI-${year}-`;
    const last = await admin
      .from('admissions_enquiries')
      .select('application_no')
      .like('application_no', `${prefix}%`)
      .order('application_no', { ascending: false })
      .limit(1);
    let next = 1;
    const lastNo = ((last.data ?? [])[0] as { application_no: string } | undefined)?.application_no;
    if (lastNo) {
      const parsed = Number.parseInt(lastNo.slice(prefix.length), 10);
      if (!Number.isNaN(parsed)) next = parsed + 1;
    }

    for (let attempt = 0; attempt < 6; attempt += 1) {
      const applicationNo = `${prefix}${String(next + attempt).padStart(4, '0')}`;
      const insert = await admin
        .from('admissions_enquiries')
        .insert({
          branch_id: branchId,
          academic_session_id: sessionId,
          application_no: applicationNo,
          applicant_full_name: fullName,
          guardian_name: guardianName || null,
          phone: phone || null,
          email: email || null,
          preferred_program: program || null,
          preferred_level: level || null,
          source: 'website',
          notes: notes || null,
          status: 'new',
          created_by: createdBy,
        })
        .select('application_no, created_at')
        .single();

      if (!insert.error) {
        return json({ data: insert.data });
      }
      if (insert.error.code !== '23505') {
        return json({ error: 'insert_failed', message: 'Could not record the application.' }, 500);
      }
    }

    return json({ error: 'insert_failed', message: 'Could not record the application.' }, 500);
  }

  /* Everything below needs a signed-in caller */
  if (!callerId) {
    return json({ error: 'unauthenticated', message: 'Please sign in again.' }, 401);
  }

  const listAuthUsers = async () => {
    const users: { id: string; email: string | null; full_name: string | null; created_at: string }[] = [];
    let page = 1;
    for (;;) {
      const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 200 });
      if (error || !data) break;
      for (const user of data.users) {
        const meta = (user.user_metadata ?? {}) as { full_name?: string };
        users.push({
          id: user.id,
          email: user.email ?? null,
          full_name: meta.full_name ?? null,
          created_at: user.created_at,
        });
      }
      if (data.users.length < 200) break;
      page += 1;
    }
    return users;
  };

  if (action === 'staff-directory') {
    if (!(await hasAnyRole(callerId, MANAGER_ROLES))) {
      return json({ error: 'forbidden', message: 'You cannot view the staff directory.' }, 403);
    }
    const { data, error } = await admin
      .from('user_roles')
      .select('user_id, role')
      .in('role', STAFF_ROLES);
    if (error) return json({ error: 'query_failed', message: error.message }, 500);

    const roleRows = (data ?? []) as { user_id: string; role: string }[];
    const ids = [...new Set(roleRows.map((row) => row.user_id))];
    if (ids.length === 0) return json({ data: [] });
    const profiles = await admin.from('profiles').select('id, full_name, email').in('id', ids);

    const staff = ids.map((id) => {
      const profile = ((profiles.data ?? []) as { id: string; full_name: string; email: string | null }[]).find(
        (row) => row.id === id,
      );
      return {
        user_id: id,
        full_name: profile?.full_name ?? 'Staff member',
        email: profile?.email ?? null,
        roles: roleRows.filter((row) => row.user_id === id).map((row) => row.role),
      };
    });

    staff.sort((a, b) => a.full_name.localeCompare(b.full_name));
    return json({ data: staff });
  }

  if (action === 'directory') {
    if (!(await hasAnyRole(callerId, ['super_admin']))) {
      return json({ error: 'forbidden', message: 'Only the super administrator can manage roles.' }, 403);
    }

    const [authUsers, profilesRes, rolesRes] = await Promise.all([
      listAuthUsers(),
      admin.from('profiles').select('id, full_name, email, preferred_locale'),
      admin.from('user_roles').select('user_id, role, assigned_at'),
    ]);
    if (profilesRes.error) return json({ error: 'query_failed', message: profilesRes.error.message }, 500);
    if (rolesRes.error) return json({ error: 'query_failed', message: rolesRes.error.message }, 500);

    const profiles = (profilesRes.data ?? []) as {
      id: string;
      full_name: string;
      email: string | null;
      preferred_locale: string;
    }[];
    const roleRows = (rolesRes.data ?? []) as { user_id: string; role: string; assigned_at: string }[];

    const people = authUsers.map((user) => {
      const profile = profiles.find((row) => row.id === user.id);
      return {
        user_id: user.id,
        full_name: profile?.full_name || user.full_name || user.email || 'Unnamed account',
        email: profile?.email || user.email,
        locale: profile?.preferred_locale ?? 'ar',
        has_profile: Boolean(profile),
        signed_up_at: user.created_at,
        roles: roleRows.filter((row) => row.user_id === user.id).map((row) => row.role),
      };
    });

    people.sort((a, b) => a.full_name.localeCompare(b.full_name));
    return json({ data: people });
  }

  return json({ error: 'unknown_action', message: 'Unsupported action.' }, 400);
});