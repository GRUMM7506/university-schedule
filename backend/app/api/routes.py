"""Main API router: CRUD entities, dashboard, schedule views, attendance, gradebook, statistics.

Auth, user-management, profile and permissions have been moved to dedicated
sub-modules (auth.py, users.py, profile.py, permissions.py).
"""
from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import distinct, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.auth import _student_for_user
from app.api.crud_router import build_crud_router
from app.api.deps import get_current_user, require_any, require_permission
from app.db.session import get_db
from app.models import (
    Attendance,
    Classroom,
    DisciplineLoad,
    Execution,
    Faculty,
    Performance,
    Schedule,
    Speciality,
    Student,
    StudentGroup,
    StudyWeek,
    Subject,
    Teacher,
    User,
)
from app.schemas import (
    AttendanceBulkItem,
    AttendanceCreate,
    AttendanceRead,
    AttendanceUpdate,
    ClassroomCreate,
    ClassroomRead,
    ClassroomUpdate,
    DashboardStats,
    DisciplineLoadCreate,
    DisciplineLoadRead,
    DisciplineLoadUpdate,
    ExecutionCreate,
    ExecutionRead,
    ExecutionUpdate,
    FacultyCreate,
    FacultyRead,
    FacultyStatistics,
    FacultyUpdate,
    PerformanceCreate,
    PerformanceRead,
    PerformanceUpdate,
    RegisterStudent,
    ScheduleCreate,
    ScheduleRead,
    ScheduleUpdate,
    ScheduleView,
    SpecialityCreate,
    SpecialityRead,
    SpecialityUpdate,
    StudentCreate,
    StudentGroupCreate,
    StudentGroupRead,
    StudentGroupUpdate,
    StudentImportRow,
    StudentRead,
    StudentUpdate,
    StudyWeekCreate,
    StudyWeekRead,
    StudyWeekUpdate,
    SubjectCreate,
    SubjectRead,
    SubjectUpdate,
    TeacherCreate,
    TeacherImportRow,
    TeacherRead,
    TeacherUpdate,
    TemplateResponse,
    Token,
)

api_router = APIRouter(prefix="/api")


# ─── /me ──────────────────────────────────────────────────────────────────────

@api_router.get("/me")
def me(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Return current user info with role-specific linked entity."""
    result = {"id": user.id, "username": user.username, "role": user.role}
    if user.role == "Student":
        student = _student_for_user(db, user)
        if student:
            result["linked_id"] = student.id
            result["fio"] = student.fio
    elif user.role == "Teacher":
        teacher = db.scalar(select(Teacher).where(Teacher.user_id == user.id))
        if teacher:
            result["linked_id"] = teacher.id
            result["fio"] = teacher.fio
    elif user.role == "Guest":
        result["fio"] = user.username
    return result


# ─── Dashboard ────────────────────────────────────────────────────────────────

@api_router.get("/dashboard", response_model=DashboardStats, dependencies=[Depends(require_permission("dashboard.view"))])
def dashboard(db: Session = Depends(get_db)):
    return DashboardStats(
        students=db.scalar(select(func.count(Student.id))) or 0,
        teachers=db.scalar(select(func.count(Teacher.id))) or 0,
        groups=db.scalar(select(func.count(StudentGroup.id))) or 0,
        faculties=db.scalar(select(func.count(Faculty.id))) or 0,
    )


@api_router.get("/dashboard/student/{student_id}", dependencies=[Depends(require_any)])
def student_dashboard(student_id: int, db: Session = Depends(get_db)):
    student = db.scalar(select(Student).where(Student.id == student_id))
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    attendance_total = db.scalar(select(func.count(Attendance.id)).where(Attendance.student_id == student_id)) or 0
    attendance_present = db.scalar(
        select(func.count(Attendance.id)).where(Attendance.student_id == student_id, Attendance.mark == 2)
    ) or 0
    avg_mark_row = db.scalar(
        select(func.avg(Performance.mark)).where(Performance.student_id == student_id)
    )
    avg_mark = round(float(avg_mark_row), 2) if avg_mark_row else 0.0
    grades_count = db.scalar(select(func.count(Performance.id)).where(Performance.student_id == student_id)) or 0
    return {
        "fio": student.fio,
        "group_id": student.group_id,
        "attendance_total": attendance_total,
        "attendance_present": attendance_present,
        "attendance_rate": round(attendance_present / attendance_total * 100, 1) if attendance_total > 0 else 0,
        "avg_mark": avg_mark,
        "grades_count": grades_count,
    }


@api_router.get("/dashboard/teacher/{teacher_id}", dependencies=[Depends(require_any)])
def teacher_dashboard(teacher_id: int, db: Session = Depends(get_db)):
    teacher = db.scalar(select(Teacher).where(Teacher.id == teacher_id))
    if not teacher:
        raise HTTPException(status_code=404, detail="Teacher not found")
    disciplines_count = db.scalar(
        select(func.count(DisciplineLoad.id)).where(DisciplineLoad.teacher_id == teacher_id)
    ) or 0
    groups_ids = db.scalars(
        select(distinct(DisciplineLoad.group_id)).where(DisciplineLoad.teacher_id == teacher_id)
    ).all()
    students_count = db.scalar(
        select(func.count(Student.id)).where(Student.group_id.in_(groups_ids))
    ) or 0
    schedule_count = db.scalar(
        select(func.count(Schedule.id)).where(Schedule.teacher_id == teacher_id)
    ) or 0
    return {
        "fio": teacher.fio,
        "position": teacher.position,
        "disciplines_count": disciplines_count,
        "groups_count": len(groups_ids),
        "students_count": students_count,
        "schedule_count": schedule_count,
    }


# ─── CRUD Entities ─────────────────────────────────────────────────────────────

entities = [
    ("faculties", Faculty, FacultyCreate, FacultyUpdate, FacultyRead, False, True),
    ("specialities", Speciality, SpecialityCreate, SpecialityUpdate, SpecialityRead, False, True),
    ("classrooms", Classroom, ClassroomCreate, ClassroomUpdate, ClassroomRead, False, True),
    ("subjects", Subject, SubjectCreate, SubjectUpdate, SubjectRead, False, True),
    ("groups", StudentGroup, StudentGroupCreate, StudentGroupUpdate, StudentGroupRead, False, True),
    ("teachers", Teacher, TeacherCreate, TeacherUpdate, TeacherRead, False, True),
    ("students", Student, StudentCreate, StudentUpdate, StudentRead, False, True),
    ("disciplines", DisciplineLoad, DisciplineLoadCreate, DisciplineLoadUpdate, DisciplineLoadRead, False, True),
    ("study-weeks", StudyWeek, StudyWeekCreate, StudyWeekUpdate, StudyWeekRead, False, True),
    ("attendance", Attendance, AttendanceCreate, AttendanceUpdate, AttendanceRead, True, False),
    ("performance", Performance, PerformanceCreate, PerformanceUpdate, PerformanceRead, True, False),
    ("execution", Execution, ExecutionCreate, ExecutionUpdate, ExecutionRead, True, False),
    ("schedule", Schedule, ScheduleCreate, ScheduleUpdate, ScheduleRead, True, False),
]

for prefix, model, create_schema, update_schema, read_schema, staff_read, any_read in entities:
    api_router.include_router(
        build_crud_router(
            model=model,
            create_schema=create_schema,
            update_schema=update_schema,
            read_schema=read_schema,
            staff_read=staff_read,
            any_read=any_read,
            permission_prefix=prefix,
        ),
        prefix=f"/{prefix}",
        tags=[prefix],
    )


# ─── Schedule Views ────────────────────────────────────────────────────────────

def schedule_view_stmt():
    return (
        select(
            Schedule.id,
            Schedule.day_num,
            Schedule.pair_num,
            Subject.name.label("subject"),
            Schedule.subject_id,
            Teacher.fio.label("teacher"),
            Schedule.teacher_id,
            Classroom.number.label("classroom"),
            Schedule.classroom_id,
            Schedule.lesson_type,
            StudentGroup.name.label("group"),
            Schedule.group_id,
            StudyWeek.name.label("week"),
            Schedule.study_week_id,
        )
        .join(Subject, Subject.id == Schedule.subject_id)
        .join(Teacher, Teacher.id == Schedule.teacher_id)
        .join(Classroom, Classroom.id == Schedule.classroom_id)
        .join(StudentGroup, StudentGroup.id == Schedule.group_id)
        .join(StudyWeek, StudyWeek.id == Schedule.study_week_id)
        .order_by(Schedule.day_num, Schedule.pair_num)
    )


@api_router.get("/schedule/group/{group_id}", response_model=list[ScheduleView], dependencies=[Depends(require_permission("schedule.view"))])
def group_schedule(group_id: int, week_id: int | None = None, db: Session = Depends(get_db)):
    stmt = schedule_view_stmt().where(Schedule.group_id == group_id)
    if week_id:
        stmt = stmt.where(Schedule.study_week_id == week_id)
    return [ScheduleView(**row._asdict()) for row in db.execute(stmt).all()]


@api_router.get("/schedule/teacher/{teacher_id}", response_model=list[ScheduleView], dependencies=[Depends(require_permission("schedule.view"))])
def teacher_schedule(teacher_id: int, week_id: int | None = None, db: Session = Depends(get_db)):
    stmt = schedule_view_stmt().where(Schedule.teacher_id == teacher_id)
    if week_id:
        stmt = stmt.where(Schedule.study_week_id == week_id)
    return [ScheduleView(**row._asdict()) for row in db.execute(stmt).all()]


@api_router.get("/schedule/student/{student_id}", response_model=list[ScheduleView], dependencies=[Depends(require_permission("schedule.view"))])
def student_schedule(student_id: int, week_id: int | None = None, db: Session = Depends(get_db)):
    student = db.scalar(select(Student).where(Student.id == student_id))
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    stmt = schedule_view_stmt().where(Schedule.group_id == student.group_id)
    if week_id:
        stmt = stmt.where(Schedule.study_week_id == week_id)
    return [ScheduleView(**row._asdict()) for row in db.execute(stmt).all()]


# ─── Student Detail Endpoints ──────────────────────────────────────────────────

@api_router.get("/students/{student_id}/attendance", response_model=list[AttendanceRead], dependencies=[Depends(require_permission("attendance.view"))])
def student_attendance(student_id: int, db: Session = Depends(get_db)):
    """Get student attendance records ordered by date descending"""
    return db.scalars(select(Attendance).where(Attendance.student_id == student_id).order_by(Attendance.day_date.desc())).all()


@api_router.get("/students/{student_id}/performance", response_model=list[PerformanceRead], dependencies=[Depends(require_permission("performance.view"))])
def student_performance(student_id: int, db: Session = Depends(get_db)):
    """Get student performance records ordered by tour number"""
    return db.scalars(select(Performance).where(Performance.student_id == student_id).order_by(Performance.tour_num)).all()


# ─── Attendance Bulk ───────────────────────────────────────────────────────────

@api_router.post("/attendance/bulk", response_model=list[AttendanceRead], dependencies=[Depends(require_permission("attendance.edit"))])
def save_attendance_bulk(items: list[AttendanceBulkItem], db: Session = Depends(get_db)):
    """Upsert attendance records. All items are saved atomically — the whole
    batch is rolled back if any record violates a constraint (T4 fix)."""
    saved = []
    try:
        for item in items:
            existing = db.scalar(
                select(Attendance).where(
                    Attendance.student_id == item.student_id,
                    Attendance.day_date == item.day_date,
                    Attendance.pair_num == item.pair_num,
                )
            )
            if existing:
                existing.mark = item.mark
                saved.append(existing)
            else:
                record = Attendance(**item.model_dump())
                db.add(record)
                saved.append(record)
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=400, detail="Конфликт данных в записи посещаемости")
    return saved


# ─── Gradebook ────────────────────────────────────────────────────────────────

@api_router.get("/gradebook", dependencies=[Depends(require_permission("gradebook.view"))])
def gradebook(group_id: int | None = None, discipline_id: int | None = None, db: Session = Depends(get_db)):
    """Returns gradebook: list of students with their performance marks."""
    query = (
        select(
            Student.id.label("student_id"),
            Student.fio.label("student_fio"),
            StudentGroup.name.label("group_name"),
            Performance.id.label("perf_id"),
            Performance.discipline_id,
            Performance.mark,
            Performance.control_type,
            Performance.tour_num,
            Subject.name.label("subject_name"),
        )
        .join(StudentGroup, StudentGroup.id == Student.group_id)
        .outerjoin(Performance, Performance.student_id == Student.id)
        .outerjoin(DisciplineLoad, DisciplineLoad.id == Performance.discipline_id)
        .outerjoin(Subject, Subject.id == DisciplineLoad.subject_id)
    )
    if group_id:
        query = query.where(Student.group_id == group_id)
    if discipline_id:
        query = query.where(Performance.discipline_id == discipline_id)
    query = query.order_by(Student.fio, Performance.discipline_id)
    rows = db.execute(query).all()
    return [dict(row._asdict()) for row in rows]


# ─── Statistics ───────────────────────────────────────────────────────────────

@api_router.get("/statistics/faculty/{faculty_id}", response_model=FacultyStatistics, dependencies=[Depends(require_permission("dashboard.view"))])
def faculty_statistics(faculty_id: int, db: Session = Depends(get_db)):
    groups_stmt = select(StudentGroup.id).join(Speciality).where(Speciality.faculty_id == faculty_id).subquery()
    students = db.scalar(select(func.count(Student.id)).where(Student.group_id.in_(select(groups_stmt.c.id)))) or 0
    groups = db.scalar(select(func.count()).select_from(groups_stmt)) or 0
    teachers = (
        db.scalar(
            select(func.count(distinct(DisciplineLoad.teacher_id))).where(
                DisciplineLoad.group_id.in_(select(groups_stmt.c.id))
            )
        )
        or 0
    )
    return FacultyStatistics(students_count=students, groups_count=groups, teachers_count=teachers)
