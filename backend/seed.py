from datetime import date, timedelta

from sqlalchemy import delete

from app.core.security import get_password_hash
from app.db.session import SessionLocal
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


def reset(db):
    from app.db.base import Base
    engine = db.get_bind()
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)


def main() -> None:
    db = SessionLocal()
    try:
        reset(db)

        faculties = [
            Faculty(name="Факультет информационных технологий"),
            Faculty(name="Экономический факультет"),
            Faculty(name="Факультет энергетики"),
            Faculty(name="Факультет педагогики"),
            Faculty(name="Юридический факультет"),
        ]
        db.add_all(faculties)
        db.flush()

        specialities = [
            Speciality(name="Программная инженерия", faculty_id=faculties[0].id),
            Speciality(name="Информационные системы", faculty_id=faculties[0].id),
            Speciality(name="Бухгалтерский учет", faculty_id=faculties[1].id),
            Speciality(name="Электроэнергетика", faculty_id=faculties[2].id),
            Speciality(name="Начальное образование", faculty_id=faculties[3].id),
        ]
        db.add_all(specialities)
        db.flush()

        classrooms = [
            Classroom(number="101", type="лк"),
            Classroom(number="202", type="кк"),
            Classroom(number="303", type="пк"),
            Classroom(number="404", type="лб"),
            Classroom(number="505", type="лк"),
        ]
        db.add_all(classrooms)

        teachers = [
            Teacher(fio="Каримов Азиз Рустамович", scientific_degree="PhD", academic_title="Доцент", position="Заведующий кафедрой", phone="+998901111111", email="karimov@uni.uz", address="Ташкент"),
            Teacher(fio="Ахмедова Дилноза Акмаловна", scientific_degree="DSc", academic_title="Профессор", position="Профессор", phone="+998902222222", email="ahmedova@uni.uz", address="Самарканд"),
            Teacher(fio="Юсупов Бахтиёр Нодирович", scientific_degree="PhD", academic_title="Доцент", position="Доцент", phone="+998903333333", email="yusupov@uni.uz", address="Бухара"),
            Teacher(fio="Саидова Малика Ильхомовна", scientific_degree=None, academic_title=None, position="Старший преподаватель", phone="+998904444444", email="saidova@uni.uz", address="Навои"),
            Teacher(fio="Назаров Тимур Алиевич", scientific_degree="PhD", academic_title="Доцент", position="Доцент", phone="+998905555555", email="nazarov@uni.uz", address="Андижан"),
        ]
        db.add_all(teachers)

        subjects = [
            Subject(name="Базы данных", semester=3, hours=120, control_type=1),
            Subject(name="Алгоритмы и структуры данных", semester=2, hours=110, control_type=1),
            Subject(name="Экономическая теория", semester=1, hours=90, control_type=0),
            Subject(name="Электротехника", semester=4, hours=100, control_type=1),
            Subject(name="Педагогика", semester=2, hours=80, control_type=0),
            Subject(name="Веб-программирование", semester=3, hours=130, control_type=1),
            Subject(name="Математический анализ", semester=1, hours=150, control_type=1),
            Subject(name="Линейная алгебра", semester=2, hours=100, control_type=1),
        ]
        db.add_all(subjects)
        db.flush()

        groups = [
            StudentGroup(name="PI-21", speciality_id=specialities[0].id, course=3),
            StudentGroup(name="IS-22", speciality_id=specialities[1].id, course=2),
            StudentGroup(name="BU-23", speciality_id=specialities[2].id, course=1),
            StudentGroup(name="EE-21", speciality_id=specialities[3].id, course=3),
            StudentGroup(name="NO-22", speciality_id=specialities[4].id, course=2),
        ]
        db.add_all(groups)
        db.flush()

        # Student whose username matches "student" (email = student@student.uz)
        students = [
            Student(fio="Алиев Шахзод", group_id=groups[0].id, phone="+998911111111", email="student@student.uz", address="Ташкент", birth_date=date(2004, 2, 12)),
            Student(fio="Валиева Нодира", group_id=groups[1].id, phone="+998912222222", email="valieva@student.uz", address="Ташкент", birth_date=date(2005, 5, 20)),
            Student(fio="Хамидов Жасур", group_id=groups[2].id, phone="+998913333333", email="hamidov@student.uz", address="Самарканд", birth_date=date(2006, 3, 18)),
            Student(fio="Рахимова Севара", group_id=groups[3].id, phone="+998914444444", email="rahimova@student.uz", address="Бухара", birth_date=date(2004, 9, 7)),
            Student(fio="Турсунов Камол", group_id=groups[4].id, phone="+998915555555", email="tursunov@student.uz", address="Фергана", birth_date=date(2005, 11, 2)),
            Student(fio="Кодиров Умид", group_id=groups[0].id, phone="+998916666666", email="kodirov@student.uz", address="Ташкент", birth_date=date(2004, 7, 3)),
            Student(fio="Мусаева Зиёда", group_id=groups[0].id, phone="+998917777777", email="musaeva@student.uz", address="Нукус", birth_date=date(2005, 1, 15)),
        ]
        db.add_all(students)
        db.flush()

        loads = [
            DisciplineLoad(subject_id=subjects[0].id, teacher_id=teachers[0].id, group_id=groups[0].id, lecture_hours=32, practical_hours=24, lab_hours=30, other_hours=10, control_hours=4),
            DisciplineLoad(subject_id=subjects[1].id, teacher_id=teachers[1].id, group_id=groups[1].id, lecture_hours=30, practical_hours=30, lab_hours=20, other_hours=10, control_hours=4),
            DisciplineLoad(subject_id=subjects[2].id, teacher_id=teachers[2].id, group_id=groups[2].id, lecture_hours=28, practical_hours=32, lab_hours=0, other_hours=12, control_hours=2),
            DisciplineLoad(subject_id=subjects[3].id, teacher_id=teachers[3].id, group_id=groups[3].id, lecture_hours=34, practical_hours=20, lab_hours=28, other_hours=10, control_hours=4),
            DisciplineLoad(subject_id=subjects[4].id, teacher_id=teachers[4].id, group_id=groups[4].id, lecture_hours=26, practical_hours=30, lab_hours=0, other_hours=12, control_hours=2),
            DisciplineLoad(subject_id=subjects[5].id, teacher_id=teachers[0].id, group_id=groups[0].id, lecture_hours=20, practical_hours=40, lab_hours=40, other_hours=10, control_hours=4),
            DisciplineLoad(subject_id=subjects[6].id, teacher_id=teachers[1].id, group_id=groups[0].id, lecture_hours=40, practical_hours=30, lab_hours=0, other_hours=10, control_hours=4),
        ]
        db.add_all(loads)
        db.flush()

        base = date(2026, 9, 7)
        weeks = [StudyWeek(name=f"{i + 1}-неделя", start_date=base + timedelta(days=7 * i), end_date=base + timedelta(days=7 * i + 5)) for i in range(8)]
        db.add_all(weeks)
        db.flush()

        # More attendance records for student[0] (Алиев Шахзод)
        attendance_marks_data = [2, 2, 1, 2, 0, 2, 2, 2, 1, 2, 2, 0, 2, 2, 2]
        for idx, mark_val in enumerate(attendance_marks_data):
            db.add(Attendance(
                student_id=students[0].id,
                day_date=base + timedelta(days=idx),
                pair_num=(idx % 4) + 1,
                mark=mark_val,
            ))

        # Attendance for other students
        for i, student in enumerate(students[1:5], 1):
            for j in range(5):
                db.add(Attendance(
                    student_id=student.id,
                    day_date=base + timedelta(days=i + j),
                    pair_num=(j % 4) + 1,
                    mark=(i + j) % 3,
                ))

        # Performance for student[0] — multiple subjects
        perf_marks = [5, 4, 5, 3, 4, 5, 4]
        for idx, load in enumerate(loads[:3]):
            db.add(Performance(
                student_id=students[0].id,
                discipline_id=load.id,
                teacher_id=teachers[idx % 5].id,
                control_type=subjects[idx].control_type,
                tour_num=1,
                mark=perf_marks[idx],
            ))
        # Also for other students
        for i, student in enumerate(students[1:5], 1):
            db.add(Performance(
                student_id=student.id,
                discipline_id=loads[i % len(loads)].id,
                teacher_id=teachers[i % 5].id,
                control_type=subjects[i % 5].control_type,
                tour_num=1,
                mark=min(5, i + 1),
            ))

        # Execution records
        for i, teacher in enumerate(teachers):
            if i < len(loads):
                db.add(Execution(
                    teacher_id=teacher.id,
                    discipline_id=loads[i].id,
                    lectures=8 + i,
                    practicals=6 + i,
                    labs=i,
                    other_works=2 + i,
                ))

        # Schedule — multiple entries per week
        schedule_entries = [
            (weeks[0].id, 1, 1, subjects[0].id, teachers[0].id, 0, classrooms[0].id, groups[0].id),
            (weeks[0].id, 1, 2, subjects[5].id, teachers[0].id, 2, classrooms[1].id, groups[0].id),
            (weeks[0].id, 2, 1, subjects[6].id, teachers[1].id, 0, classrooms[0].id, groups[0].id),
            (weeks[0].id, 2, 3, subjects[0].id, teachers[0].id, 1, classrooms[2].id, groups[0].id),
            (weeks[0].id, 3, 2, subjects[5].id, teachers[0].id, 2, classrooms[3].id, groups[0].id),
            (weeks[0].id, 4, 1, subjects[6].id, teachers[1].id, 0, classrooms[0].id, groups[0].id),
            (weeks[0].id, 5, 2, subjects[0].id, teachers[0].id, 1, classrooms[2].id, groups[0].id),
            (weeks[0].id, 1, 1, subjects[1].id, teachers[1].id, 0, classrooms[1].id, groups[1].id),
            (weeks[0].id, 2, 2, subjects[2].id, teachers[2].id, 0, classrooms[2].id, groups[2].id),
            (weeks[0].id, 3, 1, subjects[3].id, teachers[3].id, 2, classrooms[3].id, groups[3].id),
            (weeks[0].id, 4, 3, subjects[4].id, teachers[4].id, 0, classrooms[4].id, groups[4].id),
        ]
        for entry in schedule_entries:
            db.add(Schedule(
                study_week_id=entry[0], day_num=entry[1], pair_num=entry[2],
                subject_id=entry[3], teacher_id=entry[4], lesson_type=entry[5],
                classroom_id=entry[6], group_id=entry[7],
            ))

        db.add_all([
            User(username="admin", hashed_password=get_password_hash("admin123"), role="Admin"),
            User(username="teacher", hashed_password=get_password_hash("teacher123"), role="Teacher"),
            User(username="student", hashed_password=get_password_hash("student123"), role="Student"),
        ])
        db.commit()
        print("Seed completed.")
        print("Users: admin/admin123 | teacher/teacher123 | student/student123")
    finally:
        db.close()


if __name__ == "__main__":
    main()
