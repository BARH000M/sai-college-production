--
-- PostgreSQL database dump
--

\restrict dysd8sdQgGOIjnJZgAcGeJXsRKYBLxT5OMrrUaPRAcnWlvVd9UyCK0q29UlSKaz

-- Dumped from database version 17.11
-- Dumped by pg_dump version 17.11

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

--
-- Data for Name: academic_sessions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.academic_sessions (id, name, starts_on, ends_on, is_active) FROM stdin;
\.


--
-- Data for Name: branches; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.branches (id, name, code, address, is_active, created_at) FROM stdin;
\.


--
-- Data for Name: admissions_enquiries; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.admissions_enquiries (id, branch_id, academic_session_id, application_no, applicant_full_name, guardian_name, phone, email, preferred_program, preferred_level, source, notes, status, assigned_to, created_by, created_at, updated_at, closed_at) FROM stdin;
\.


--
-- Data for Name: classes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.classes (id, branch_id, session_id, name, program, capacity, teacher_id, created_at, is_active) FROM stdin;
\.


--
-- Data for Name: attendance_sessions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.attendance_sessions (id, branch_id, academic_session_id, class_id, attendance_date, start_time, end_time, status, created_by, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: students; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.students (id, user_id, branch_id, admission_no, full_name, date_of_birth, class_id, status, created_at) FROM stdin;
\.


--
-- Data for Name: attendance_records; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.attendance_records (id, attendance_session_id, student_id, status, note, marked_by, marked_at, updated_at) FROM stdin;
\.


--
-- Data for Name: audit_logs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.audit_logs (id, actor_user_id, action, entity_type, entity_id, metadata, created_at) FROM stdin;
\.


--
-- Data for Name: branch_memberships; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.branch_memberships (user_id, branch_id, is_active) FROM stdin;
\.


--
-- Data for Name: parent_student_links; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.parent_student_links (parent_user_id, student_id, verified_at, verified_by) FROM stdin;
\.


--
-- Data for Name: profiles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.profiles (id, full_name, email, phone, preferred_locale, created_at, updated_at) FROM stdin;
78c951ec-aa54-4a5c-86e3-953b16f23ce8	SAI College Super Administrator	info@saicollege.com	\N	ar	2026-11-07 20:14:23.901749+00	2026-11-07 20:14:23.901749+00
\.


--
-- Data for Name: user_roles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_roles (user_id, role, assigned_by, assigned_at) FROM stdin;
78c951ec-aa54-4a5c-86e3-953b16f23ce8	super_admin	78c951ec-aa54-4a5c-86e3-953b16f23ce8	2026-11-07 20:14:23.901749+00
\.


--
-- PostgreSQL database dump complete
--

\unrestrict dysd8sdQgGOIjnJZgAcGeJXsRKYBLxT5OMrrUaPRAcnWlvVd9UyCK0q29UlSKaz

