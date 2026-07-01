from datetime import date
from enum import IntEnum, StrEnum

from sqlalchemy import CheckConstraint, Date, Enum, ForeignKey, Index, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class ClassroomType(StrEnum):
    computer = "кк"
    lecture = "лк"
    practical = "пк"
    laboratory = "лб"


class ControlType(IntEnum):
    credit = 0
    exam = 1


class AttendanceMark(IntEnum):
    absent = 0
    late = 1
    present = 2


class PerformanceMark(IntEnum):
    no_admission = 0
    absent = 1
    unsatisfactory = 2
    satisfactory = 3
    good = 4
    excellent = 5


class LessonType(IntEnum):
    lecture = 0
    practical = 1
    laboratory = 2
    other = 3


class UserRole(StrEnum):
    admin = "Admin"
    teacher = "Teacher"
    student = "Student"
    guest = "Guest"


class Faculty(Base):
    __tablename__ = "faculties"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(160), unique=True, nullable=False, index=True)

    specialities: Mapped[list["Speciality"]] = relationship(back_populates="faculty", cascade="all, delete-orphan")


class Speciality(Base):
    __tablename__ = "specialities"
    __table_args__ = (UniqueConstraint("faculty_id", "name", name="uq_speciality_faculty_name"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(160), nullable=False, index=True)
    faculty_id: Mapped[int] = mapped_column(ForeignKey("faculties.id", ondelete="CASCADE"), nullable=False, index=True)

    faculty: Mapped[Faculty] = relationship(back_populates="specialities")
    groups: Mapped[list["StudentGroup"]] = relationship(back_populates="speciality", cascade="all, delete-orphan")


class Classroom(Base):
    __tablename__ = "classrooms"
    __table_args__ = (CheckConstraint("type IN ('кк', 'лк', 'пк', 'лб')", name="ck_classroom_type"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    number: Mapped[str] = mapped_column(String(40), unique=True, nullable=False, index=True)
    type: Mapped[str] = mapped_column(String(2), nullable=False)


class Subject(Base):
    __tablename__ = "subjects"
    __table_args__ = (
        CheckConstraint("semester BETWEEN 1 AND 12", name="ck_subject_semester"),
        CheckConstraint("hours > 0", name="ck_subject_hours"),
        UniqueConstraint("name", "semester", name="uq_subject_name_semester"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(180), nullable=False, index=True)
    semester: Mapped[int] = mapped_column(Integer, nullable=False)
    hours: Mapped[int] = mapped_column(Integer, nullable=False)
    control_type: Mapped[int] = mapped_column(Integer, nullable=False)


class StudentGroup(Base):
    __tablename__ = "student_groups"
    __table_args__ = (
        CheckConstraint("course BETWEEN 1 AND 4", name="ck_group_course"),
        UniqueConstraint("speciality_id", "name", name="uq_group_speciality_name"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(80), nullable=False, index=True)
    speciality_id: Mapped[int] = mapped_column(ForeignKey("specialities.id", ondelete="RESTRICT"), nullable=False, index=True)
    course: Mapped[int] = mapped_column(Integer, nullable=False)

    speciality: Mapped[Speciality] = relationship(back_populates="groups")
    students: Mapped[list["Student"]] = relationship(back_populates="group", cascade="all, delete-orphan")


class Teacher(Base):
    __tablename__ = "teachers"

    id: Mapped[int] = mapped_column(primary_key=True)
    fio: Mapped[str] = mapped_column(String(180), nullable=False, index=True)
    scientific_degree: Mapped[str | None] = mapped_column(String(120))
    academic_title: Mapped[str | None] = mapped_column(String(120))
    position: Mapped[str | None] = mapped_column(String(120), nullable=True, index=True)
    phone: Mapped[str | None] = mapped_column(String(40))
    address: Mapped[str | None] = mapped_column(String(240))
    email: Mapped[str | None] = mapped_column(String(160), unique=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True, index=True)

    user: Mapped["User"] = relationship(back_populates="teacher", uselist=False)


class Student(Base):
    __tablename__ = "students"

    id: Mapped[int] = mapped_column(primary_key=True)
    fio: Mapped[str] = mapped_column(String(180), nullable=False, index=True)
    group_id: Mapped[int] = mapped_column(ForeignKey("student_groups.id", ondelete="RESTRICT"), nullable=False, index=True)
    phone: Mapped[str | None] = mapped_column(String(40))
    address: Mapped[str | None] = mapped_column(String(240))
    email: Mapped[str | None] = mapped_column(String(160), unique=True, index=True)
    birth_date: Mapped[date] = mapped_column(Date, nullable=False)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True, index=True)

    group: Mapped[StudentGroup] = relationship(back_populates="students")
    user: Mapped["User"] = relationship(back_populates="student")


class DisciplineLoad(Base):
    __tablename__ = "discipline_loads"
    __table_args__ = (
        CheckConstraint("lecture_hours >= 0 AND practical_hours >= 0 AND lab_hours >= 0 AND other_hours >= 0 AND control_hours >= 0", name="ck_load_hours_non_negative"),
        UniqueConstraint("subject_id", "teacher_id", "group_id", name="uq_load_subject_teacher_group"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    subject_id: Mapped[int] = mapped_column(ForeignKey("subjects.id", ondelete="RESTRICT"), nullable=False, index=True)
    teacher_id: Mapped[int] = mapped_column(ForeignKey("teachers.id", ondelete="RESTRICT"), nullable=False, index=True)
    group_id: Mapped[int] = mapped_column(ForeignKey("student_groups.id", ondelete="CASCADE"), nullable=False, index=True)
    lecture_hours: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    practical_hours: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    lab_hours: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    other_hours: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    control_hours: Mapped[int] = mapped_column(Integer, default=0, nullable=False)


class StudyWeek(Base):
    __tablename__ = "study_weeks"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(80), unique=True, nullable=False)
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date] = mapped_column(Date, nullable=False)


class Attendance(Base):
    __tablename__ = "attendance"
    __table_args__ = (
        CheckConstraint("pair_num BETWEEN 1 AND 8", name="ck_attendance_pair"),
        UniqueConstraint("student_id", "day_date", "pair_num", name="uq_attendance_student_date_pair"),
        Index("ix_attendance_day_pair", "day_date", "pair_num"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    student_id: Mapped[int] = mapped_column(ForeignKey("students.id", ondelete="CASCADE"), nullable=False, index=True)
    day_date: Mapped[date] = mapped_column(Date, nullable=False)
    pair_num: Mapped[int] = mapped_column(Integer, nullable=False)
    mark: Mapped[int] = mapped_column(Integer, nullable=False)


class Performance(Base):
    __tablename__ = "performance"
    __table_args__ = (
        CheckConstraint("tour_num BETWEEN 1 AND 4", name="ck_performance_tour"),
        UniqueConstraint("student_id", "discipline_id", "tour_num", name="uq_performance_student_discipline_tour"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    student_id: Mapped[int] = mapped_column(ForeignKey("students.id", ondelete="CASCADE"), nullable=False, index=True)
    discipline_id: Mapped[int] = mapped_column(ForeignKey("discipline_loads.id", ondelete="CASCADE"), nullable=False, index=True)
    teacher_id: Mapped[int] = mapped_column(ForeignKey("teachers.id", ondelete="RESTRICT"), nullable=False, index=True)
    control_type: Mapped[int] = mapped_column(Integer, nullable=False)
    tour_num: Mapped[int] = mapped_column(Integer, nullable=False)
    mark: Mapped[int] = mapped_column(Integer, nullable=False)


class Execution(Base):
    __tablename__ = "execution"
    __table_args__ = (
        CheckConstraint("lectures >= 0 AND practicals >= 0 AND labs >= 0 AND other_works >= 0", name="ck_execution_non_negative"),
        UniqueConstraint("teacher_id", "discipline_id", name="uq_execution_teacher_discipline"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    teacher_id: Mapped[int] = mapped_column(ForeignKey("teachers.id", ondelete="RESTRICT"), nullable=False, index=True)
    discipline_id: Mapped[int] = mapped_column(ForeignKey("discipline_loads.id", ondelete="CASCADE"), nullable=False, index=True)
    lectures: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    practicals: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    labs: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    other_works: Mapped[int] = mapped_column(Integer, default=0, nullable=False)


class Schedule(Base):
    __tablename__ = "schedule"
    __table_args__ = (
        CheckConstraint("day_num BETWEEN 1 AND 6", name="ck_schedule_day"),
        CheckConstraint("pair_num BETWEEN 1 AND 8", name="ck_schedule_pair"),
        UniqueConstraint("study_week_id", "day_num", "pair_num", "group_id", name="uq_schedule_group_slot"),
        UniqueConstraint("study_week_id", "day_num", "pair_num", "teacher_id", name="uq_schedule_teacher_slot"),
        UniqueConstraint("study_week_id", "day_num", "pair_num", "classroom_id", name="uq_schedule_classroom_slot"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    study_week_id: Mapped[int] = mapped_column(ForeignKey("study_weeks.id", ondelete="CASCADE"), nullable=False, index=True)
    day_num: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    pair_num: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    subject_id: Mapped[int] = mapped_column(ForeignKey("subjects.id", ondelete="RESTRICT"), nullable=False, index=True)
    teacher_id: Mapped[int] = mapped_column(ForeignKey("teachers.id", ondelete="RESTRICT"), nullable=False, index=True)
    lesson_type: Mapped[int] = mapped_column(Integer, nullable=False)
    classroom_id: Mapped[int] = mapped_column(ForeignKey("classrooms.id", ondelete="RESTRICT"), nullable=False, index=True)
    group_id: Mapped[int] = mapped_column(ForeignKey("student_groups.id", ondelete="CASCADE"), nullable=False, index=True)


class User(Base):
    __tablename__ = "users"
    __table_args__ = (CheckConstraint("role IN ('Admin', 'Teacher', 'Student', 'Guest')", name="ck_user_role"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    username: Mapped[str] = mapped_column(String(80), unique=True, nullable=False, index=True)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[str] = mapped_column(String(20), nullable=False)
    refresh_token: Mapped[str | None] = mapped_column(String(512), nullable=True)

    student: Mapped["Student"] = relationship(back_populates="user", uselist=False)
    teacher: Mapped["Teacher"] = relationship(back_populates="user", uselist=False)


class UserPermission(Base):
    __tablename__ = "user_permissions"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    permission: Mapped[str] = mapped_column(String(64), nullable=False)
    is_granted: Mapped[bool] = mapped_column(nullable=False, default=True)

    __table_args__ = (UniqueConstraint("user_id", "permission", name="uq_user_permission"),)

