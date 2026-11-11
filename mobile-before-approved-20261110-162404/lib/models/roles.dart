enum AppRole {superAdmin,admin,teacher,accountant,receptionist,librarian,student,parent,contentEditor}
extension RoleText on AppRole {
 String get db => switch(this){AppRole.superAdmin=>'super_admin',AppRole.contentEditor=>'content_editor',_=>name};
 String get arabic => switch(this){AppRole.superAdmin=>'المدير العام',AppRole.admin=>'الإدارة',AppRole.teacher=>'المعلم',AppRole.accountant=>'المحاسب',AppRole.receptionist=>'الاستقبال',AppRole.librarian=>'أمين المكتبة',AppRole.student=>'الطالب',AppRole.parent=>'ولي الأمر',AppRole.contentEditor=>'محرر المحتوى'};
 static AppRole? parse(String s){for(final r in AppRole.values){if(r.db==s)return r;}return null;}
}
enum Feature {home,modules,learning,courses,classes,roster,lesson,student,notifications,profile,finance,staff,admissions,library,content,attendance,users}
const roleFeatures=<AppRole,Set<Feature>>{
 AppRole.superAdmin:{...Feature.values},
 AppRole.admin:{Feature.home,Feature.modules,Feature.courses,Feature.classes,Feature.roster,Feature.student,Feature.notifications,Feature.profile,Feature.staff,Feature.admissions,Feature.library,Feature.attendance,Feature.users,Feature.content},
 AppRole.teacher:{Feature.home,Feature.learning,Feature.courses,Feature.classes,Feature.roster,Feature.lesson,Feature.student,Feature.notifications,Feature.profile,Feature.attendance,Feature.library},
 AppRole.accountant:{Feature.home,Feature.modules,Feature.finance,Feature.notifications,Feature.profile},
 AppRole.receptionist:{Feature.home,Feature.modules,Feature.classes,Feature.admissions,Feature.attendance,Feature.notifications,Feature.profile},
 AppRole.librarian:{Feature.home,Feature.modules,Feature.library,Feature.notifications,Feature.profile},
 AppRole.student:{Feature.home,Feature.learning,Feature.courses,Feature.lesson,Feature.notifications,Feature.profile,Feature.library},
 AppRole.parent:{Feature.home,Feature.student,Feature.notifications,Feature.profile},
 AppRole.contentEditor:{Feature.home,Feature.modules,Feature.content,Feature.courses,Feature.lesson,Feature.notifications,Feature.profile,Feature.library},
};
Set<Feature> allowedFeatures(Set<AppRole> roles)=>{for(final r in roles)...roleFeatures[r]??<Feature>{}};
