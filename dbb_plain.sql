--
-- PostgreSQL database dump
--

-- Dumped from database version 17.5
-- Dumped by pg_dump version 17.5

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: alembic_version; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.alembic_version (
    version_num character varying(32) NOT NULL
);


ALTER TABLE public.alembic_version OWNER TO postgres;

--
-- Name: attendance; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.attendance (
    id integer NOT NULL,
    student_id integer NOT NULL,
    day_date date NOT NULL,
    pair_num integer NOT NULL,
    mark integer NOT NULL,
    CONSTRAINT ck_attendance_pair CHECK (((pair_num >= 1) AND (pair_num <= 8)))
);


ALTER TABLE public.attendance OWNER TO postgres;

--
-- Name: attendance_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.attendance_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.attendance_id_seq OWNER TO postgres;

--
-- Name: attendance_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.attendance_id_seq OWNED BY public.attendance.id;


--
-- Name: classrooms; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.classrooms (
    id integer NOT NULL,
    number character varying(40) NOT NULL,
    type character varying(2) NOT NULL,
    CONSTRAINT ck_classroom_type CHECK (((type)::text = ANY ((ARRAY['кк'::character varying, 'лк'::character varying, 'пк'::character varying, 'лб'::character varying])::text[])))
);


ALTER TABLE public.classrooms OWNER TO postgres;

--
-- Name: classrooms_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.classrooms_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.classrooms_id_seq OWNER TO postgres;

--
-- Name: classrooms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.classrooms_id_seq OWNED BY public.classrooms.id;


--
-- Name: discipline_loads; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.discipline_loads (
    id integer NOT NULL,
    subject_id integer NOT NULL,
    teacher_id integer NOT NULL,
    group_id integer NOT NULL,
    lecture_hours integer NOT NULL,
    practical_hours integer NOT NULL,
    lab_hours integer NOT NULL,
    other_hours integer NOT NULL,
    control_hours integer NOT NULL,
    CONSTRAINT ck_load_hours_non_negative CHECK (((lecture_hours >= 0) AND (practical_hours >= 0) AND (lab_hours >= 0) AND (other_hours >= 0) AND (control_hours >= 0)))
);


ALTER TABLE public.discipline_loads OWNER TO postgres;

--
-- Name: discipline_loads_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.discipline_loads_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.discipline_loads_id_seq OWNER TO postgres;

--
-- Name: discipline_loads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.discipline_loads_id_seq OWNED BY public.discipline_loads.id;


--
-- Name: execution; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.execution (
    id integer NOT NULL,
    teacher_id integer NOT NULL,
    discipline_id integer NOT NULL,
    lectures integer NOT NULL,
    practicals integer NOT NULL,
    labs integer NOT NULL,
    other_works integer NOT NULL,
    CONSTRAINT ck_execution_non_negative CHECK (((lectures >= 0) AND (practicals >= 0) AND (labs >= 0) AND (other_works >= 0)))
);


ALTER TABLE public.execution OWNER TO postgres;

--
-- Name: execution_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.execution_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.execution_id_seq OWNER TO postgres;

--
-- Name: execution_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.execution_id_seq OWNED BY public.execution.id;


--
-- Name: faculties; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.faculties (
    id integer NOT NULL,
    name character varying(160) NOT NULL
);


ALTER TABLE public.faculties OWNER TO postgres;

--
-- Name: faculties_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.faculties_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.faculties_id_seq OWNER TO postgres;

--
-- Name: faculties_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.faculties_id_seq OWNED BY public.faculties.id;


--
-- Name: performance; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.performance (
    id integer NOT NULL,
    student_id integer NOT NULL,
    discipline_id integer NOT NULL,
    teacher_id integer NOT NULL,
    control_type integer NOT NULL,
    tour_num integer NOT NULL,
    mark integer NOT NULL,
    CONSTRAINT ck_performance_tour CHECK (((tour_num >= 1) AND (tour_num <= 4)))
);


ALTER TABLE public.performance OWNER TO postgres;

--
-- Name: performance_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.performance_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.performance_id_seq OWNER TO postgres;

--
-- Name: performance_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.performance_id_seq OWNED BY public.performance.id;


--
-- Name: schedule; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.schedule (
    id integer NOT NULL,
    study_week_id integer NOT NULL,
    day_num integer NOT NULL,
    pair_num integer NOT NULL,
    subject_id integer NOT NULL,
    teacher_id integer NOT NULL,
    lesson_type integer NOT NULL,
    classroom_id integer NOT NULL,
    group_id integer NOT NULL,
    CONSTRAINT ck_schedule_day CHECK (((day_num >= 1) AND (day_num <= 6))),
    CONSTRAINT ck_schedule_pair CHECK (((pair_num >= 1) AND (pair_num <= 8)))
);


ALTER TABLE public.schedule OWNER TO postgres;

--
-- Name: schedule_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.schedule_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.schedule_id_seq OWNER TO postgres;

--
-- Name: schedule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.schedule_id_seq OWNED BY public.schedule.id;


--
-- Name: specialities; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.specialities (
    id integer NOT NULL,
    name character varying(160) NOT NULL,
    faculty_id integer NOT NULL
);


ALTER TABLE public.specialities OWNER TO postgres;

--
-- Name: specialities_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.specialities_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.specialities_id_seq OWNER TO postgres;

--
-- Name: specialities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.specialities_id_seq OWNED BY public.specialities.id;


--
-- Name: student_groups; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.student_groups (
    id integer NOT NULL,
    name character varying(80) NOT NULL,
    speciality_id integer NOT NULL,
    course integer NOT NULL,
    CONSTRAINT ck_group_course CHECK (((course >= 1) AND (course <= 6)))
);


ALTER TABLE public.student_groups OWNER TO postgres;

--
-- Name: student_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.student_groups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.student_groups_id_seq OWNER TO postgres;

--
-- Name: student_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.student_groups_id_seq OWNED BY public.student_groups.id;


--
-- Name: students; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.students (
    id integer NOT NULL,
    fio character varying(180) NOT NULL,
    group_id integer NOT NULL,
    phone character varying(40),
    address character varying(240),
    email character varying(160),
    birth_date date NOT NULL,
    user_id integer
);


ALTER TABLE public.students OWNER TO postgres;

--
-- Name: students_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.students_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.students_id_seq OWNER TO postgres;

--
-- Name: students_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.students_id_seq OWNED BY public.students.id;


--
-- Name: study_weeks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.study_weeks (
    id integer NOT NULL,
    name character varying(80) NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL
);


ALTER TABLE public.study_weeks OWNER TO postgres;

--
-- Name: study_weeks_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.study_weeks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.study_weeks_id_seq OWNER TO postgres;

--
-- Name: study_weeks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.study_weeks_id_seq OWNED BY public.study_weeks.id;


--
-- Name: subjects; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.subjects (
    id integer NOT NULL,
    name character varying(180) NOT NULL,
    semester integer NOT NULL,
    hours integer NOT NULL,
    control_type integer NOT NULL,
    CONSTRAINT ck_subject_hours CHECK ((hours > 0)),
    CONSTRAINT ck_subject_semester CHECK (((semester >= 1) AND (semester <= 12)))
);


ALTER TABLE public.subjects OWNER TO postgres;

--
-- Name: subjects_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.subjects_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.subjects_id_seq OWNER TO postgres;

--
-- Name: subjects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.subjects_id_seq OWNED BY public.subjects.id;


--
-- Name: teachers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.teachers (
    id integer NOT NULL,
    fio character varying(180) NOT NULL,
    scientific_degree character varying(120),
    academic_title character varying(120),
    "position" character varying(120),
    phone character varying(40),
    address character varying(240),
    email character varying(160),
    user_id integer
);


ALTER TABLE public.teachers OWNER TO postgres;

--
-- Name: teachers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.teachers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.teachers_id_seq OWNER TO postgres;

--
-- Name: teachers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.teachers_id_seq OWNED BY public.teachers.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id integer NOT NULL,
    username character varying(80) NOT NULL,
    hashed_password character varying(255) NOT NULL,
    role character varying(20) NOT NULL,
    CONSTRAINT ck_user_role CHECK (((role)::text = ANY ((ARRAY['Admin'::character varying, 'Teacher'::character varying, 'Student'::character varying])::text[])))
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: attendance id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attendance ALTER COLUMN id SET DEFAULT nextval('public.attendance_id_seq'::regclass);


--
-- Name: classrooms id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.classrooms ALTER COLUMN id SET DEFAULT nextval('public.classrooms_id_seq'::regclass);


--
-- Name: discipline_loads id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.discipline_loads ALTER COLUMN id SET DEFAULT nextval('public.discipline_loads_id_seq'::regclass);


--
-- Name: execution id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.execution ALTER COLUMN id SET DEFAULT nextval('public.execution_id_seq'::regclass);


--
-- Name: faculties id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.faculties ALTER COLUMN id SET DEFAULT nextval('public.faculties_id_seq'::regclass);


--
-- Name: performance id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.performance ALTER COLUMN id SET DEFAULT nextval('public.performance_id_seq'::regclass);


--
-- Name: schedule id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule ALTER COLUMN id SET DEFAULT nextval('public.schedule_id_seq'::regclass);


--
-- Name: specialities id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.specialities ALTER COLUMN id SET DEFAULT nextval('public.specialities_id_seq'::regclass);


--
-- Name: student_groups id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_groups ALTER COLUMN id SET DEFAULT nextval('public.student_groups_id_seq'::regclass);


--
-- Name: students id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.students ALTER COLUMN id SET DEFAULT nextval('public.students_id_seq'::regclass);


--
-- Name: study_weeks id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.study_weeks ALTER COLUMN id SET DEFAULT nextval('public.study_weeks_id_seq'::regclass);


--
-- Name: subjects id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.subjects ALTER COLUMN id SET DEFAULT nextval('public.subjects_id_seq'::regclass);


--
-- Name: teachers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teachers ALTER COLUMN id SET DEFAULT nextval('public.teachers_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Data for Name: alembic_version; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.alembic_version (version_num) FROM stdin;
00a1631e4f0f
\.


--
-- Data for Name: attendance; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.attendance (id, student_id, day_date, pair_num, mark) FROM stdin;
36	10	2026-06-26	1	2
37	15	2026-06-26	1	2
38	10	2026-06-25	1	1
39	15	2026-06-25	1	2
40	10	2026-06-26	2	1
41	15	2026-06-26	2	2
\.


--
-- Data for Name: classrooms; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.classrooms (id, number, type) FROM stdin;
6	104	кк
7	105	кк
8	106	лк
9	107	лк
10	108	лк
11	801	лк
\.


--
-- Data for Name: discipline_loads; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.discipline_loads (id, subject_id, teacher_id, group_id, lecture_hours, practical_hours, lab_hours, other_hours, control_hours) FROM stdin;
9	1	11	7	32	32	0	0	6
10	2	11	7	16	16	0	0	4
11	7	10	7	64	64	0	0	6
12	8	12	7	16	16	0	2	6
\.


--
-- Data for Name: execution; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.execution (id, teacher_id, discipline_id, lectures, practicals, labs, other_works) FROM stdin;
\.


--
-- Data for Name: faculties; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.faculties (id, name) FROM stdin;
6	Естественнонаучный
7	Гуманитарный
\.


--
-- Data for Name: performance; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.performance (id, student_id, discipline_id, teacher_id, control_type, tour_num, mark) FROM stdin;
8	10	9	23	1	1	5
9	15	9	23	1	1	5
\.


--
-- Data for Name: schedule; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.schedule (id, study_week_id, day_num, pair_num, subject_id, teacher_id, lesson_type, classroom_id, group_id) FROM stdin;
16	1	1	1	1	11	0	6	7
17	1	1	2	1	11	0	6	7
18	1	2	3	7	10	0	11	7
\.


--
-- Data for Name: specialities; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.specialities (id, name, faculty_id) FROM stdin;
7	ПМиИ	6
8	Геология	6
9	ХФММ	6
10	МО	7
11	ГМУ	7
12	Лингвистика	7
\.


--
-- Data for Name: student_groups; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.student_groups (id, name, speciality_id, course) FROM stdin;
6	ПМиИ-1	7	1
7	ПМиИ-2	7	2
8	ПМиИ-3	7	3
9	ПМиИ-4	7	4
10	Геология-1	8	1
11	Геология-2	8	2
12	Геология-3	8	3
13	Геология-4	8	4
14	ХФММ-1	9	1
15	ХФММ-2	9	2
16	ХФММ-3	9	3
17	ХФММ-4	9	4
18	МО-1	10	1
19	МО-2	10	2
20	МО-3	10	3
21	МО-4	10	4
22	ГМУ-1	11	1
23	ГМУ-2	11	2
24	ГМУ-3	11	3
25	ГМУ-4	11	4
26	Лингвистика-1	12	1
27	Лингвистика-2	12	2
28	Лингвистика-3	12	3
29	Лингвистика-4	12	4
\.


--
-- Data for Name: students; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.students (id, fio, group_id, phone, address, email, birth_date, user_id) FROM stdin;
10	Косимов Мухаммаджон	7	\N	\N	student@student.uz	2006-04-02	\N
15	Акбаров Акбар	7	\N	\N	test@gmail.com	2006-05-07	\N
17	Акбаров Акбар Набижонович	7	\N	\N	\N	2006-05-07	4
18	test test	7	\N	\N	\N	2006-01-01	3
\.


--
-- Data for Name: study_weeks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.study_weeks (id, name, start_date, end_date) FROM stdin;
1	1-неделя	2026-09-07	2026-09-12
2	2-неделя	2026-09-14	2026-09-19
3	3-неделя	2026-09-21	2026-09-26
4	4-неделя	2026-09-28	2026-10-03
5	5-неделя	2026-10-05	2026-10-10
6	6-неделя	2026-10-12	2026-10-17
7	7-неделя	2026-10-19	2026-10-24
8	8-неделя	2026-10-26	2026-10-31
\.


--
-- Data for Name: subjects; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.subjects (id, name, semester, hours, control_type) FROM stdin;
1	Базы данных	3	120	1
2	Алгоритмы и структуры данных	2	110	1
3	Экономическая теория	1	90	0
4	Электротехника	4	100	1
5	Педагогика	2	80	0
7	Математический анализ	1	150	1
8	Линейная алгебра	2	100	1
\.


--
-- Data for Name: teachers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.teachers (id, fio, scientific_degree, academic_title, "position", phone, address, email, user_id) FROM stdin;
6	Шамолов Абдулвохид Абдуллаевич	Доктор философских наук	Профессор	Профессор кафедры	+992 (37) 221-99-41	ул. Бохтар, 35/1	info@msu.tj	\N
10	Одинабеков Джасур Музофирович	Кандидат физико-математических наук	Доцент	Заведующий кафедрой	\N	\N	\N	\N
11	Бобоев Шараф Асрорович	\N	\N	Старший преподаватель кафедры математики и естественных наук	\N	\N	\N	\N
12	Казиджанова Нодира Марифатовна	Кандидат технических наук	Доцент	Доцент кафедры фундаментальных и естественных наук	\N	\N	\N	\N
13	Абдукаримов Махмадсалим Файзуллоевич	Кандидат физико-математических наук	Доцент	Доцент кафедры фундаментальных и естественных наук	\N	\N	mahmadsalim_86@mail.ru	\N
14	Салихов Фарид Салохиддинович	Доктор геолого-минералогических наук	Профессор	Профессор кафедры математики и естественных наук	+992 (904) 000-999	\N	ffaarriidd@bk.ru	\N
15	Ибадов Рустам Махмудович	Доктор физ.-мат. наук	Профессор	Профессор	\N	\N	\N	\N
16	Гадоев Махмадали Гафурович	Канд. физ.-мат. наук	Доцент	Доцент	\N	\N	\N	\N
17	Рахмонов Зарулло Хусенович	Доктор физ.-мат. наук	Профессор	Профессор	\N	\N	\N	\N
18	Салихов Фарид Салохиддинович	Доктор геол.-мин. наук	Профессор	Профессор	\N	\N	\N	\N
19	Махмадрасулов Бободжон Саймахмудович	Канд. ист. наук	Доцент	Заведующий кафедрой	\N	\N	\N	\N
20	Диноршох Азиз Мусо	Доктор юрид. наук	Профессор	Профессор	\N	\N	\N	\N
21	Джамшедов Парвона Джамшедович	Доктор филол. наук	Профессор	Профессор	\N	\N	\N	\N
22	Ризоева Фарзона Ахмадджоновна	Канд. филол. наук	Доцент	Доцент	\N	\N	\N	\N
23	test	\N	\N	Преподаватель	\N	\N	teacher@uni.uz	\N
24	Одинабеков Джасур Музофирович	\N	\N	Преподаватель	\N	\N	\N	2
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, username, hashed_password, role) FROM stdin;
1	admin	$2b$12$plTF7lUqkv4usq7k2MZqGeO3No4wlxs5GjkBvmC0Iqa83nCWyQ.0y	Admin
2	teacher	$2b$12$pcm0GQIEJph/.aRrDyo4uOT.OdOcO2ivRsbHJqKr0NIHdX/HBqbmG	Teacher
3	student	$2b$12$3zl3T42QpRpF5DIY0OCj0u5Ucbg/Kj0946sKUDwsWO/wDt/YY5Dg6	Student
4	student2	$2b$12$FQLMEGVUSK1Ubc3aIVF3TejUxqzI4Hs/AJLUZ46JkFvMjboKaS.ri	Student
\.


--
-- Name: attendance_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.attendance_id_seq', 41, true);


--
-- Name: classrooms_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.classrooms_id_seq', 11, true);


--
-- Name: discipline_loads_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.discipline_loads_id_seq', 12, true);


--
-- Name: execution_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.execution_id_seq', 6, true);


--
-- Name: faculties_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.faculties_id_seq', 7, true);


--
-- Name: performance_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.performance_id_seq', 9, true);


--
-- Name: schedule_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.schedule_id_seq', 18, true);


--
-- Name: specialities_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.specialities_id_seq', 12, true);


--
-- Name: student_groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.student_groups_id_seq', 29, true);


--
-- Name: students_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.students_id_seq', 18, true);


--
-- Name: study_weeks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.study_weeks_id_seq', 8, true);


--
-- Name: subjects_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.subjects_id_seq', 8, true);


--
-- Name: teachers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.teachers_id_seq', 24, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 4, true);


--
-- Name: alembic_version alembic_version_pkc; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.alembic_version
    ADD CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num);


--
-- Name: attendance attendance_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_pkey PRIMARY KEY (id);


--
-- Name: classrooms classrooms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.classrooms
    ADD CONSTRAINT classrooms_pkey PRIMARY KEY (id);


--
-- Name: discipline_loads discipline_loads_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.discipline_loads
    ADD CONSTRAINT discipline_loads_pkey PRIMARY KEY (id);


--
-- Name: execution execution_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.execution
    ADD CONSTRAINT execution_pkey PRIMARY KEY (id);


--
-- Name: faculties faculties_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.faculties
    ADD CONSTRAINT faculties_pkey PRIMARY KEY (id);


--
-- Name: performance performance_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.performance
    ADD CONSTRAINT performance_pkey PRIMARY KEY (id);


--
-- Name: schedule schedule_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule
    ADD CONSTRAINT schedule_pkey PRIMARY KEY (id);


--
-- Name: specialities specialities_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.specialities
    ADD CONSTRAINT specialities_pkey PRIMARY KEY (id);


--
-- Name: student_groups student_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_groups
    ADD CONSTRAINT student_groups_pkey PRIMARY KEY (id);


--
-- Name: students students_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_pkey PRIMARY KEY (id);


--
-- Name: students students_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_user_id_key UNIQUE (user_id);


--
-- Name: study_weeks study_weeks_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.study_weeks
    ADD CONSTRAINT study_weeks_name_key UNIQUE (name);


--
-- Name: study_weeks study_weeks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.study_weeks
    ADD CONSTRAINT study_weeks_pkey PRIMARY KEY (id);


--
-- Name: subjects subjects_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT subjects_pkey PRIMARY KEY (id);


--
-- Name: teachers teachers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teachers
    ADD CONSTRAINT teachers_pkey PRIMARY KEY (id);


--
-- Name: teachers teachers_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teachers
    ADD CONSTRAINT teachers_user_id_key UNIQUE (user_id);


--
-- Name: attendance uq_attendance_student_date_pair; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT uq_attendance_student_date_pair UNIQUE (student_id, day_date, pair_num);


--
-- Name: execution uq_execution_teacher_discipline; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.execution
    ADD CONSTRAINT uq_execution_teacher_discipline UNIQUE (teacher_id, discipline_id);


--
-- Name: student_groups uq_group_speciality_name; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_groups
    ADD CONSTRAINT uq_group_speciality_name UNIQUE (speciality_id, name);


--
-- Name: discipline_loads uq_load_subject_teacher_group; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.discipline_loads
    ADD CONSTRAINT uq_load_subject_teacher_group UNIQUE (subject_id, teacher_id, group_id);


--
-- Name: performance uq_performance_student_discipline_tour; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.performance
    ADD CONSTRAINT uq_performance_student_discipline_tour UNIQUE (student_id, discipline_id, tour_num);


--
-- Name: schedule uq_schedule_classroom_slot; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule
    ADD CONSTRAINT uq_schedule_classroom_slot UNIQUE (study_week_id, day_num, pair_num, classroom_id);


--
-- Name: schedule uq_schedule_group_slot; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule
    ADD CONSTRAINT uq_schedule_group_slot UNIQUE (study_week_id, day_num, pair_num, group_id);


--
-- Name: schedule uq_schedule_teacher_slot; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule
    ADD CONSTRAINT uq_schedule_teacher_slot UNIQUE (study_week_id, day_num, pair_num, teacher_id);


--
-- Name: specialities uq_speciality_faculty_name; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.specialities
    ADD CONSTRAINT uq_speciality_faculty_name UNIQUE (faculty_id, name);


--
-- Name: subjects uq_subject_name_semester; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT uq_subject_name_semester UNIQUE (name, semester);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: ix_attendance_day_pair; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_attendance_day_pair ON public.attendance USING btree (day_date, pair_num);


--
-- Name: ix_attendance_student_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_attendance_student_id ON public.attendance USING btree (student_id);


--
-- Name: ix_classrooms_number; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX ix_classrooms_number ON public.classrooms USING btree (number);


--
-- Name: ix_discipline_loads_group_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_discipline_loads_group_id ON public.discipline_loads USING btree (group_id);


--
-- Name: ix_discipline_loads_subject_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_discipline_loads_subject_id ON public.discipline_loads USING btree (subject_id);


--
-- Name: ix_discipline_loads_teacher_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_discipline_loads_teacher_id ON public.discipline_loads USING btree (teacher_id);


--
-- Name: ix_execution_discipline_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_execution_discipline_id ON public.execution USING btree (discipline_id);


--
-- Name: ix_execution_teacher_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_execution_teacher_id ON public.execution USING btree (teacher_id);


--
-- Name: ix_faculties_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX ix_faculties_name ON public.faculties USING btree (name);


--
-- Name: ix_performance_discipline_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_performance_discipline_id ON public.performance USING btree (discipline_id);


--
-- Name: ix_performance_student_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_performance_student_id ON public.performance USING btree (student_id);


--
-- Name: ix_performance_teacher_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_performance_teacher_id ON public.performance USING btree (teacher_id);


--
-- Name: ix_schedule_classroom_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_schedule_classroom_id ON public.schedule USING btree (classroom_id);


--
-- Name: ix_schedule_day_num; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_schedule_day_num ON public.schedule USING btree (day_num);


--
-- Name: ix_schedule_group_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_schedule_group_id ON public.schedule USING btree (group_id);


--
-- Name: ix_schedule_pair_num; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_schedule_pair_num ON public.schedule USING btree (pair_num);


--
-- Name: ix_schedule_study_week_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_schedule_study_week_id ON public.schedule USING btree (study_week_id);


--
-- Name: ix_schedule_subject_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_schedule_subject_id ON public.schedule USING btree (subject_id);


--
-- Name: ix_schedule_teacher_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_schedule_teacher_id ON public.schedule USING btree (teacher_id);


--
-- Name: ix_specialities_faculty_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_specialities_faculty_id ON public.specialities USING btree (faculty_id);


--
-- Name: ix_specialities_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_specialities_name ON public.specialities USING btree (name);


--
-- Name: ix_student_groups_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_student_groups_name ON public.student_groups USING btree (name);


--
-- Name: ix_student_groups_speciality_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_student_groups_speciality_id ON public.student_groups USING btree (speciality_id);


--
-- Name: ix_students_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_students_email ON public.students USING btree (email);


--
-- Name: ix_students_fio; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_students_fio ON public.students USING btree (fio);


--
-- Name: ix_students_group_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_students_group_id ON public.students USING btree (group_id);


--
-- Name: ix_subjects_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_subjects_name ON public.subjects USING btree (name);


--
-- Name: ix_teachers_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_teachers_email ON public.teachers USING btree (email);


--
-- Name: ix_teachers_fio; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_teachers_fio ON public.teachers USING btree (fio);


--
-- Name: ix_teachers_position; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_teachers_position ON public.teachers USING btree ("position");


--
-- Name: ix_users_username; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX ix_users_username ON public.users USING btree (username);


--
-- Name: attendance attendance_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: discipline_loads discipline_loads_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.discipline_loads
    ADD CONSTRAINT discipline_loads_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.student_groups(id) ON DELETE CASCADE;


--
-- Name: discipline_loads discipline_loads_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.discipline_loads
    ADD CONSTRAINT discipline_loads_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id) ON DELETE RESTRICT;


--
-- Name: discipline_loads discipline_loads_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.discipline_loads
    ADD CONSTRAINT discipline_loads_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.teachers(id) ON DELETE RESTRICT;


--
-- Name: execution execution_discipline_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.execution
    ADD CONSTRAINT execution_discipline_id_fkey FOREIGN KEY (discipline_id) REFERENCES public.discipline_loads(id) ON DELETE CASCADE;


--
-- Name: execution execution_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.execution
    ADD CONSTRAINT execution_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.teachers(id) ON DELETE RESTRICT;


--
-- Name: performance performance_discipline_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.performance
    ADD CONSTRAINT performance_discipline_id_fkey FOREIGN KEY (discipline_id) REFERENCES public.discipline_loads(id) ON DELETE CASCADE;


--
-- Name: performance performance_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.performance
    ADD CONSTRAINT performance_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: performance performance_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.performance
    ADD CONSTRAINT performance_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.teachers(id) ON DELETE RESTRICT;


--
-- Name: schedule schedule_classroom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule
    ADD CONSTRAINT schedule_classroom_id_fkey FOREIGN KEY (classroom_id) REFERENCES public.classrooms(id) ON DELETE RESTRICT;


--
-- Name: schedule schedule_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule
    ADD CONSTRAINT schedule_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.student_groups(id) ON DELETE CASCADE;


--
-- Name: schedule schedule_study_week_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule
    ADD CONSTRAINT schedule_study_week_id_fkey FOREIGN KEY (study_week_id) REFERENCES public.study_weeks(id) ON DELETE CASCADE;


--
-- Name: schedule schedule_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule
    ADD CONSTRAINT schedule_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id) ON DELETE RESTRICT;


--
-- Name: schedule schedule_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule
    ADD CONSTRAINT schedule_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.teachers(id) ON DELETE RESTRICT;


--
-- Name: specialities specialities_faculty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.specialities
    ADD CONSTRAINT specialities_faculty_id_fkey FOREIGN KEY (faculty_id) REFERENCES public.faculties(id) ON DELETE CASCADE;


--
-- Name: student_groups student_groups_speciality_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_groups
    ADD CONSTRAINT student_groups_speciality_id_fkey FOREIGN KEY (speciality_id) REFERENCES public.specialities(id) ON DELETE RESTRICT;


--
-- Name: students students_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.student_groups(id) ON DELETE RESTRICT;


--
-- Name: students students_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: teachers teachers_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teachers
    ADD CONSTRAINT teachers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

