import 'package:supabase_flutter/supabase_flutter.dart';

const admissionsPageSize = 50;

const admissionStatusLabels = <String, String>{
  'new': 'جديد',
  'contacted': 'تم التواصل',
  'assessment': 'التقييم',
  'accepted': 'مقبول',
  'enrolled': 'مسجل',
  'rejected': 'مرفوض',
  'withdrawn': 'منسحب',
};

const editableAdmissionStatuses = <String, String>{
  'new': 'جديد',
  'contacted': 'تم التواصل',
  'assessment': 'التقييم',
  'accepted': 'مقبول',
  'rejected': 'مرفوض',
  'withdrawn': 'منسحب',
};

abstract interface class AdmissionsData {
  Future<List<Map<String, dynamic>>> loadBranches();

  Future<List<Map<String, dynamic>>> loadEnquiries({
    required String branchId,
    required int offset,
    String? status,
  });

  Future<void> updateStatus(String enquiryId, String status);

  Future<Map<String, dynamic>> enroll(String enquiryId);
}

class AdmissionsRepository implements AdmissionsData {
  AdmissionsRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> loadBranches() async {
    final rows = await _client.from('branches').select('id,name').order('name');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> loadEnquiries({
    required String branchId,
    required int offset,
    String? status,
  }) async {
    var query = _client
        .from('admissions_enquiries')
        .select(
          'id,application_no,applicant_full_name,guardian_name,phone,email,'
          'preferred_program,preferred_level,notes,status,created_at',
        )
        .eq('branch_id', branchId);
    if (status != null) query = query.eq('status', status);
    final rows = await query
        .order('created_at', ascending: false)
        .range(offset, offset + admissionsPageSize - 1);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  @override
  Future<void> updateStatus(String enquiryId, String status) async {
    if (!editableAdmissionStatuses.containsKey(status)) {
      throw ArgumentError.value(
        status,
        'status',
        'Unsupported admission status',
      );
    }
    await _client.rpc(
      'sai_admissions_set_status',
      params: {'p_enquiry_id': enquiryId, 'p_status': status},
    );
  }

  @override
  Future<Map<String, dynamic>> enroll(String enquiryId) async {
    final result = await _client.rpc(
      'sai_admissions_enroll',
      params: {'p_enquiry_id': enquiryId},
    );
    if (result is! Map) {
      throw StateError('The enrollment RPC returned an invalid response.');
    }
    final response = Map<String, dynamic>.from(result);
    if (response['student_id'] is! String ||
        response['admission_no'] is! String) {
      throw StateError('The enrollment RPC returned an incomplete response.');
    }
    return response;
  }
}
