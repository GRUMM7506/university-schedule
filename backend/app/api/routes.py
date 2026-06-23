from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import distinct, func, select
from sqlalchemy.orm import Session

from app.api.crud_router import build_crud_router
from app.api.deps import require_admin, require_staff
from app.core.security import create_access_token, verify_password
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
    LoginRequest,
    PerformanceCreate,
    PerformanceRead,
    PerformanceUpdate,
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
    StudentRead,
    StudentUpdate,
    StudyWeekCreate,
    StudyWeekRead,
    StudyWeekUpdate,
    SubjectCreate,
    SubjectRead,
    SubjectUpdate,
    TeacherCreate,
    TeacherRead,
    TeacherUpdate,
    Token,
)
from app.services.crud import CRUDService

api_router = APIRouter(prefix="/api")


@api_router.post("/auth/login", response_model=Token)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.username == payload.username))
    if user is None or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid username or password")
    return Token(access_token=create_access_token(user.username, user.role), role=user.role)


@api_router.get("/dashboard", response_model=DashboardStats, dependencies=[Depends(require_staff)])
def dashboard(db: Session = Depends(get_db)):
    return DashboardStats(
        students=db.scalar(select(func.count(Student.id))) or 0,
        teachers=db.scalar(select(func.count(Teacher.id))) or 0,
        groups=db.scalar(select(func.count(StudentGroup.id))) or 0,
        faculties=db.scalar(select(func.count(Faculty.id))) or 0,
    )


entities = [
    ("faculties", Faculty, FacultyCreate, FacultyUpdate, FacultyRead, False),
    ("specialities", Speciality, SpecialityCreate, SpecialityUpdate, SpecialityRead, False),
    ("classrooms", Classroom, ClassroomCreate, ClassroomUpdate, ClassroomRead, False),
    ("subjects", Subject, SubjectCreate, SubjectUpdate, SubjectRead, False),
    ("groups", StudentGroup, StudentGroupCreate, StudentGroupUpdate, StudentGroupRead, False),
    ("teachers", Teacher, TeacherCreate, TeacherUpdate, TeacherRead, False),
    ("students", Student, StudentCreate, StudentUpdate, StudentRead, False),
    ("disciplines", DisciplineLoad, DisciplineLoadCreate, DisciplineLoadUpdate, DisciplineLoadRead, False),
    ("study-weeks", StudyWeek, StudyWeekCreate, StudyWeekUpdate, StudyWeekRead, False),
    ("attendance", Attendance, AttendanceCreate, AttendanceUpdate, AttendanceRead, True),
    ("performance", Performance, PerformanceCreate, PerformanceUpdate, PerformanceRead, True),
    ("execution", Execution, ExecutionCreate, ExecutionUpdate, ExecutionRead, False),
    ("schedule", Schedule, ScheduleCreate, ScheduleUpdate, ScheduleRead, True),
]

for prefix, model, create_schema, update_schema, read_schema, staff_read in entities:
    api_router.include_router(
        build_crud_router(
            model=model,
            create_schema=create_schema,
            update_schema=update_schema,
            read_schema=read_schema,
            staff_read=staff_read,
        ),
        prefix=f"/{prefix}",
        tags=[prefix],
    )


def schedule_view_stmt():
    return (
        select(
            Schedule.id,
            Schedule.day_num,
            Schedule.pair_num,
            Subject.name.label("subject"),
            Teacher.fio.label("teacher"),
            Classroom.number.label("classroom"),
            Schedule.lesson_type,
            StudentGroup.name.label("group"),
            StudyWeek.name.label("week"),
        )
        .join(Subject, Subject.id == Schedule.subject_id)
        .join(Teacher, Teacher.id == Schedule.teacher_id)
        .join(Classroom, Classroom.id == Schedule.classroom_id)
        .join(StudentGroup, StudentGroup.id == Schedule.group_id)
        .join(StudyWeek, StudyWeek.id == Schedule.study_week_id)
        .order_by(Schedule.day_num, Schedule.pair_num)
    )


@api_router.get("/schedule/group/{group_id}", response_model=list[ScheduleView], dependencies=[Depends(require_staff)])
def group_schedule(group_id: int, week_id: int | None = None, db: Session = Depends(get_db)):
    stmt = schedule_view_stmt().where(Schedule.group_id == group_id)
    if week_id:
        stmt = stmt.where(Schedule.study_week_id == week_id)
    return [ScheduleView(**row._asdict()) for row in db.execute(stmt).all()]


@api_router.get("/schedule/teacher/{teacher_id}", response_model=list[ScheduleView], dependencies=[Depends(require_staff)])
def teacher_schedule(teacher_id: int, week_id: int | None = None, db: Session = Depends(get_db)):
    stmt = schedule_view_stmt().where(Schedule.teacher_id == teacher_id)
    if week_id:
        stmt = stmt.where(Schedule.study_week_id == week_id)
    return [ScheduleView(**row._asdict()) for row in db.execute(stmt).all()]


@api_router.get("/students/{student_id}/attendance", response_model=list[AttendanceRead], dependencies=[Depends(require_staff)])
def student_attendance(student_id: int, db: Session = Depends(get_db)):
    return db.scalars(select(Attendance).where(Attendance.student_id == student_id).order_by(Attendance.day_date.desc())).all()


@api_router.get("/students/{student_id}/performance", response_model=list[PerformanceRead], dependencies=[Depends(require_staff)])
def student_performance(student_id: int, db: Session = Depends(get_db)):
    return db.scalars(select(Performance).where(Performance.student_id == student_id).order_by(Performance.tour_num)).all()


@api_router.post("/attendance/bulk", response_model=list[AttendanceRead], dependencies=[Depends(require_staff)])
def save_attendance_bulk(items: list[AttendanceBulkItem], db: Session = Depends(get_db)):
    service = CRUDService(Attendance)
    saved = []
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
            saved.append(Attendance(**item.model_dump()))
            db.add(saved[-1])
    service._commit(db)
    return saved


@api_router.get("/statistics/faculty/{faculty_id}", response_model=FacultyStatistics, dependencies=[Depends(require_staff)])
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
