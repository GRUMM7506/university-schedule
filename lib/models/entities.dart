import 'package:flutter/material.dart';
import 'entity_model.dart';

const classroomTypes = {
  'кк': 'Компьютерный',
  'лк': 'Лекционная',
  'пк': 'Практическая',
  'лб': 'Лаборатория',
};
const controlTypes = {'0': 'Зачет', '1': 'Экзамен'};
const lessonTypes = {
  '0': 'Лекция',
  '1': 'Практика',
  '2': 'Лабораторная',
  '3': 'Другое',
};
const attendanceMarks = {
  '0': 'Отсутствовал',
  '1': 'Опоздал',
  '2': 'Присутствовал',
};
const performanceMarks = {
  '0': 'Недопуск',
  '1': 'Неявка',
  '2': 'Неудовл.',
  '3': 'Удовл.',
  '4': 'Хорошо',
  '5': 'Отлично',
};

/// Lesson type colors for schedule cards
const lessonTypeColors = {
  0: Color(0xFF3B82F6), // Лекция — синий
  1: Color(0xFF10B981), // Практика — зеленый
  2: Color(0xFFF59E0B), // Лабораторная — оранжевый
  3: Color(0xFF8B5CF6), // Другое — фиолетовый
};

/// Icons for each entity in the navigation
const entityIcons = {
  '/faculties': Icons.account_balance_outlined,
  '/specialities': Icons.auto_stories_outlined,
  '/groups': Icons.groups_outlined,
  '/students': Icons.person_outlined,
  '/teachers': Icons.cast_for_education_outlined,
  '/subjects': Icons.menu_book_outlined,
  '/disciplines': Icons.science_outlined,
  '/classrooms': Icons.meeting_room_outlined,
  '/study-weeks': Icons.date_range_outlined,
  '/execution': Icons.assignment_turned_in_outlined,
};

const entityDefinitions = <EntityDefinition>[
  EntityDefinition(
    title: 'Факультеты',
    route: '/faculties',
    endpoint: '/faculties',
    columns: ['name'],
    fields: [EntityField(key: 'name', label: 'Название')],
  ),
  EntityDefinition(
    title: 'Специальности',
    route: '/specialities',
    endpoint: '/specialities',
    columns: ['name', 'faculty_id'],
    fields: [
      EntityField(key: 'name', label: 'Название'),
      EntityField(
        key: 'faculty_id',
        label: 'Факультет',
        type: FieldType.fkSelect,
        refEndpoint: '/faculties',
      ),
    ],
  ),
  EntityDefinition(
    title: 'Группы',
    route: '/groups',
    endpoint: '/groups',
    columns: ['name', 'speciality_id', 'course'],
    fields: [
      EntityField(key: 'name', label: 'Название'),
      EntityField(
        key: 'speciality_id',
        label: 'Специальность',
        type: FieldType.fkSelect,
        refEndpoint: '/specialities',
      ),
      EntityField(key: 'course', label: 'Курс', type: FieldType.number),
    ],
  ),
  EntityDefinition(
    title: 'Студенты',
    route: '/students',
    endpoint: '/students',
    columns: ['fio', 'group_id', 'phone', 'email'],
    fields: [
      EntityField(key: 'fio', label: 'ФИО'),
      EntityField(
        key: 'group_id',
        label: 'Группа',
        type: FieldType.fkSelect,
        refEndpoint: '/groups',
      ),
      EntityField(key: 'phone', label: 'Телефон', required: false),
      EntityField(key: 'email', label: 'Email', type: FieldType.email),
      EntityField(key: 'address', label: 'Адрес', required: false),
      EntityField(
        key: 'birth_date',
        label: 'Дата рождения',
        type: FieldType.date,
      ),
    ],
  ),
  EntityDefinition(
    title: 'Преподаватели',
    route: '/teachers',
    endpoint: '/teachers',
    columns: ['fio', 'position', 'phone'],
    fields: [
      EntityField(key: 'fio', label: 'ФИО'),
      EntityField(key: 'scientific_degree', label: 'Степень', required: false),
      EntityField(key: 'academic_title', label: 'Звание', required: false),
      EntityField(key: 'position', label: 'Должность'),
      EntityField(key: 'phone', label: 'Телефон', required: false),
      EntityField(key: 'email', label: 'Email', type: FieldType.email),
      EntityField(key: 'address', label: 'Адрес', required: false),
    ],
  ),
  EntityDefinition(
    title: 'Предметы',
    route: '/subjects',
    endpoint: '/subjects',
    columns: ['name', 'semester', 'hours', 'control_type'],
    fields: [
      EntityField(key: 'name', label: 'Название'),
      EntityField(key: 'semester', label: 'Семестр', type: FieldType.number),
      EntityField(key: 'hours', label: 'Часы', type: FieldType.number),
      EntityField(
        key: 'control_type',
        label: 'Контроль',
        type: FieldType.select,
        options: controlTypes,
      ),
    ],
  ),
  EntityDefinition(
    title: 'Дисциплины',
    route: '/disciplines',
    endpoint: '/disciplines',
    columns: ['subject_id', 'teacher_id', 'group_id'],
    fields: [
      EntityField(
        key: 'subject_id',
        label: 'Предмет',
        type: FieldType.fkSelect,
        refEndpoint: '/subjects',
      ),
      EntityField(
        key: 'teacher_id',
        label: 'Преподаватель',
        type: FieldType.fkSelect,
        refEndpoint: '/teachers',
        refLabelKey: 'fio',
      ),
      EntityField(
        key: 'group_id',
        label: 'Группа',
        type: FieldType.fkSelect,
        refEndpoint: '/groups',
      ),
      EntityField(
        key: 'lecture_hours',
        label: 'Лекции',
        type: FieldType.number,
      ),
      EntityField(
        key: 'practical_hours',
        label: 'Практика',
        type: FieldType.number,
      ),
      EntityField(
        key: 'lab_hours',
        label: 'Лабораторные',
        type: FieldType.number,
      ),
      EntityField(key: 'other_hours', label: 'Прочие', type: FieldType.number),
      EntityField(
        key: 'control_hours',
        label: 'Контроль',
        type: FieldType.number,
      ),
    ],
  ),
  EntityDefinition(
    title: 'Аудитории',
    route: '/classrooms',
    endpoint: '/classrooms',
    columns: ['number', 'type'],
    fields: [
      EntityField(key: 'number', label: 'Номер'),
      EntityField(
        key: 'type',
        label: 'Тип',
        type: FieldType.select,
        options: classroomTypes,
      ),
    ],
  ),
  EntityDefinition(
    title: 'Учебные недели',
    route: '/study-weeks',
    endpoint: '/study-weeks',
    columns: ['name', 'start_date', 'end_date'],
    fields: [
      EntityField(key: 'name', label: 'Название'),
      EntityField(key: 'start_date', label: 'Начало', type: FieldType.date),
      EntityField(key: 'end_date', label: 'Конец', type: FieldType.date),
    ],
  ),
  EntityDefinition(
    title: 'Исполнение',
    route: '/execution',
    endpoint: '/execution',
    columns: ['teacher_id', 'discipline_id', 'lectures', 'practicals'],
    fields: [
      EntityField(
        key: 'teacher_id',
        label: 'Преподаватель',
        type: FieldType.fkSelect,
        refEndpoint: '/teachers',
        refLabelKey: 'fio',
      ),
      EntityField(
        key: 'discipline_id',
        label: 'Дисциплина',
        type: FieldType.fkSelect,
        refEndpoint: '/disciplines',
        refLabelKey: 'displayName',
      ),
      EntityField(key: 'lectures', label: 'Лекции', type: FieldType.number),
      EntityField(key: 'practicals', label: 'Практика', type: FieldType.number),
      EntityField(key: 'labs', label: 'Лабораторные', type: FieldType.number),
      EntityField(
        key: 'other_works',
        label: 'Прочие работы',
        type: FieldType.number,
      ),
    ],
  ),
];

const scheduleEntityDefinition = EntityDefinition(
  title: 'Занятие',
  route: '/schedule-crud',
  endpoint: '/schedule',
  columns: [], // We use custom UI for schedule, not EntityListScreen
  fields: [
    EntityField(
      key: 'study_week_id',
      label: 'Учебная неделя',
      type: FieldType.fkSelect,
      refEndpoint: '/study-weeks',
    ),
    EntityField(
      key: 'day_num',
      label: 'День недели',
      type: FieldType.select,
      options: {
        '1': 'Понедельник',
        '2': 'Вторник',
        '3': 'Среда',
        '4': 'Четверг',
        '5': 'Пятница',
        '6': 'Суббота',
      },
    ),
    EntityField(
      key: 'pair_num',
      label: 'Пара',
      type: FieldType.select,
      options: {
        '1': '1 пара',
        '2': '2 пара',
        '3': '3 пара',
        '4': '4 пара',
        '5': '5 пара',
        '6': '6 пара',
      },
    ),
    EntityField(
      key: 'subject_id',
      label: 'Предмет',
      type: FieldType.fkSelect,
      refEndpoint: '/subjects',
    ),
    EntityField(
      key: 'teacher_id',
      label: 'Преподаватель',
      type: FieldType.fkSelect,
      refEndpoint: '/teachers',
      refLabelKey: 'fio',
    ),
    EntityField(
      key: 'lesson_type',
      label: 'Тип занятия',
      type: FieldType.select,
      options: lessonTypes,
    ),
    EntityField(
      key: 'classroom_id',
      label: 'Аудитория',
      type: FieldType.fkSelect,
      refEndpoint: '/classrooms',
      refLabelKey: 'number',
    ),
    EntityField(
      key: 'group_id',
      label: 'Группа',
      type: FieldType.fkSelect,
      refEndpoint: '/groups',
    ),
  ],
);
