"""Centralised permission registry for role-based access + individual overrides.

Every possible permission in the app is listed below.  Each role has a
default set of granted permissions.  Individual ``UserPermission`` rows
in the database can *grant* or *deny* a permission for a specific user,
overriding the role default.

Usage
-----
.. code-block:: python

    from app.api.deps import require_permission

    @router.get("/schedule", dependencies=[Depends(require_permission("schedule.view"))])
    ...

Admin always gets every permission regardless of overrides.
"""

# ── Permission registry ──────────────────────────────────────────────────────
# Convention: "<entity>.<action>"  where action ∈ {view, edit, manage}

PERMISSION_DASHBOARD_VIEW = "dashboard.view"
PERMISSION_USERS_MANAGE = "users.manage"
PERMISSION_PERMISSIONS_MANAGE = "permissions.manage"

PERMISSION_FACULTIES_VIEW = "faculties.view"
PERMISSION_FACULTIES_EDIT = "faculties.edit"
PERMISSION_SPECIALITIES_VIEW = "specialities.view"
PERMISSION_SPECIALITIES_EDIT = "specialities.edit"
PERMISSION_GROUPS_VIEW = "groups.view"
PERMISSION_GROUPS_EDIT = "groups.edit"
PERMISSION_STUDENTS_VIEW = "students.view"
PERMISSION_STUDENTS_EDIT = "students.edit"
PERMISSION_TEACHERS_VIEW = "teachers.view"
PERMISSION_TEACHERS_EDIT = "teachers.edit"
PERMISSION_SUBJECTS_VIEW = "subjects.view"
PERMISSION_SUBJECTS_EDIT = "subjects.edit"
PERMISSION_CLASSROOMS_VIEW = "classrooms.view"
PERMISSION_CLASSROOMS_EDIT = "classrooms.edit"
PERMISSION_STUDY_WEEKS_VIEW = "study-weeks.view"
PERMISSION_STUDY_WEEKS_EDIT = "study-weeks.edit"
PERMISSION_DISCIPLINES_VIEW = "disciplines.view"
PERMISSION_DISCIPLINES_EDIT = "disciplines.edit"
PERMISSION_EXECUTION_VIEW = "execution.view"
PERMISSION_EXECUTION_EDIT = "execution.edit"

PERMISSION_SCHEDULE_VIEW = "schedule.view"
PERMISSION_SCHEDULE_EDIT = "schedule.edit"
PERMISSION_ATTENDANCE_VIEW = "attendance.view"
PERMISSION_ATTENDANCE_EDIT = "attendance.edit"
PERMISSION_PERFORMANCE_VIEW = "performance.view"
PERMISSION_PERFORMANCE_EDIT = "performance.edit"
PERMISSION_GRADEBOOK_VIEW = "gradebook.view"

# ── All permissions (used by the admin UI) ────────────────────────────────────

ALL_PERMISSIONS: list[str] = [
    PERMISSION_DASHBOARD_VIEW,
    PERMISSION_USERS_MANAGE,
    PERMISSION_PERMISSIONS_MANAGE,
    PERMISSION_FACULTIES_VIEW,
    PERMISSION_FACULTIES_EDIT,
    PERMISSION_SPECIALITIES_VIEW,
    PERMISSION_SPECIALITIES_EDIT,
    PERMISSION_GROUPS_VIEW,
    PERMISSION_GROUPS_EDIT,
    PERMISSION_STUDENTS_VIEW,
    PERMISSION_STUDENTS_EDIT,
    PERMISSION_TEACHERS_VIEW,
    PERMISSION_TEACHERS_EDIT,
    PERMISSION_SUBJECTS_VIEW,
    PERMISSION_SUBJECTS_EDIT,
    PERMISSION_CLASSROOMS_VIEW,
    PERMISSION_CLASSROOMS_EDIT,
    PERMISSION_STUDY_WEEKS_VIEW,
    PERMISSION_STUDY_WEEKS_EDIT,
    PERMISSION_DISCIPLINES_VIEW,
    PERMISSION_DISCIPLINES_EDIT,
    PERMISSION_EXECUTION_VIEW,
    PERMISSION_EXECUTION_EDIT,
    PERMISSION_SCHEDULE_VIEW,
    PERMISSION_SCHEDULE_EDIT,
    PERMISSION_ATTENDANCE_VIEW,
    PERMISSION_ATTENDANCE_EDIT,
    PERMISSION_PERFORMANCE_VIEW,
    PERMISSION_PERFORMANCE_EDIT,
    PERMISSION_GRADEBOOK_VIEW,
]

# ── Human-readable labels (for the admin UI) ──────────────────────────────────

PERMISSION_LABELS: dict[str, str] = {
    PERMISSION_DASHBOARD_VIEW: "Просмотр дашборда",
    PERMISSION_USERS_MANAGE: "Управление пользователями",
    PERMISSION_PERMISSIONS_MANAGE: "Управление правами доступа",
    PERMISSION_FACULTIES_VIEW: "Просмотр факультетов",
    PERMISSION_FACULTIES_EDIT: "Редактирование факультетов",
    PERMISSION_SPECIALITIES_VIEW: "Просмотр специальностей",
    PERMISSION_SPECIALITIES_EDIT: "Редактирование специальностей",
    PERMISSION_GROUPS_VIEW: "Просмотр групп",
    PERMISSION_GROUPS_EDIT: "Редактирование групп",
    PERMISSION_STUDENTS_VIEW: "Просмотр студентов",
    PERMISSION_STUDENTS_EDIT: "Редактирование студентов",
    PERMISSION_TEACHERS_VIEW: "Просмотр преподавателей",
    PERMISSION_TEACHERS_EDIT: "Редактирование преподавателей",
    PERMISSION_SUBJECTS_VIEW: "Просмотр предметов",
    PERMISSION_SUBJECTS_EDIT: "Редактирование предметов",
    PERMISSION_CLASSROOMS_VIEW: "Просмотр аудиторий",
    PERMISSION_CLASSROOMS_EDIT: "Редактирование аудиторий",
    PERMISSION_STUDY_WEEKS_VIEW: "Просмотр учебных недель",
    PERMISSION_STUDY_WEEKS_EDIT: "Редактирование учебных недель",
    PERMISSION_DISCIPLINES_VIEW: "Просмотр диспциплин",
    PERMISSION_DISCIPLINES_EDIT: "Редактирование диспциплин",
    PERMISSION_EXECUTION_VIEW: "Просмотр исполнения",
    PERMISSION_EXECUTION_EDIT: "Редактирование исполнения",
    PERMISSION_SCHEDULE_VIEW: "Просмотр расписания",
    PERMISSION_SCHEDULE_EDIT: "Редактирование расписания",
    PERMISSION_ATTENDANCE_VIEW: "Просмотр посещаемости",
    PERMISSION_ATTENDANCE_EDIT: "Редактирование посещаемости",
    PERMISSION_PERFORMANCE_VIEW: "Просмотр успеваемости",
    PERMISSION_PERFORMANCE_EDIT: "Редактирование успеваемости",
    PERMISSION_GRADEBOOK_VIEW: "Просмотр журнала",
}

# ── Role defaults ─────────────────────────────────────────────────────────────

_ADMIN: set[str] = set(ALL_PERMISSIONS)  # Admin gets everything

_TEACHER: set[str] = {
    PERMISSION_DASHBOARD_VIEW,
    PERMISSION_GROUPS_VIEW,
    PERMISSION_STUDENTS_VIEW,
    PERMISSION_TEACHERS_VIEW,
    PERMISSION_SUBJECTS_VIEW,
    PERMISSION_CLASSROOMS_VIEW,
    PERMISSION_STUDY_WEEKS_VIEW,
    PERMISSION_DISCIPLINES_VIEW,
    PERMISSION_EXECUTION_VIEW,
    PERMISSION_SCHEDULE_VIEW,
    PERMISSION_SCHEDULE_EDIT,
    PERMISSION_ATTENDANCE_VIEW,
    PERMISSION_ATTENDANCE_EDIT,
    PERMISSION_PERFORMANCE_VIEW,
    PERMISSION_PERFORMANCE_EDIT,
    PERMISSION_GRADEBOOK_VIEW,
}

_STUDENT: set[str] = {
    PERMISSION_DASHBOARD_VIEW,
    PERMISSION_SCHEDULE_VIEW,
    PERMISSION_ATTENDANCE_VIEW,
    PERMISSION_PERFORMANCE_VIEW,
}

_GUEST: set[str] = {
    PERMISSION_DASHBOARD_VIEW,
    PERMISSION_SCHEDULE_VIEW,
}

DEFAULT_ROLE_PERMISSIONS: dict[str, set[str]] = {
    "Admin": _ADMIN,
    "Teacher": _TEACHER,
    "Student": _STUDENT,
    "Guest": _GUEST,
}
