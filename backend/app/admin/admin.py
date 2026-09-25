"""Web admin panel (SQLAdmin) at /admin.

Roles: content manager — content only; superadmin — everything, incl. users (ban/unban) and stats.
Sign in with the email and password of a user whose `admin_role` is set.
"""
import os

from fastapi import FastAPI
from sqladmin import Admin, BaseView, ModelView, expose
from sqladmin.authentication import AuthenticationBackend
from starlette.requests import Request

from app.core.config import settings
from app.core.security import verify_password
from app.crud.user import get_user_by_email
from app.db.database import SessionLocal
from app.models import (
    AbiturientProfile,
    Achievement,
    AdminRole,
    Cluster,
    ClusterSubject,
    ExamTest,
    Lesson,
    Question,
    SchoolProfile,
    Subject,
    TestAttempt,
    Topic,
    User,
)
from app.services import packs
from app.services.stats import collect_stats


def _admin_role(request: Request):
    role = request.session.get("admin_role")
    return AdminRole(role) if role else None


class AdminAuth(AuthenticationBackend):
    async def login(self, request: Request) -> bool:
        form = await request.form()
        email, password = str(form.get("username", "")), str(form.get("password", ""))
        with SessionLocal() as db:
            user = get_user_by_email(db, email)
            if (
                user is None
                or not user.is_active
                or user.admin_role is None
                or not verify_password(password, user.password_hash)
            ):
                return False
            request.session.update({"admin_user_id": user.id, "admin_role": user.admin_role.value})
        return True

    async def logout(self, request: Request) -> bool:
        request.session.clear()
        return True

    async def authenticate(self, request: Request) -> bool:
        user_id = request.session.get("admin_user_id")
        if not user_id:
            return False
        with SessionLocal() as db:
            user = db.get(User, user_id)
            if user is None or not user.is_active or user.admin_role is None:
                request.session.clear()
                return False
            request.session["admin_role"] = user.admin_role.value
        return True


class ContentView(ModelView):
    """Visible to content managers and superadmins."""

    page_size = 50

    def is_accessible(self, request: Request) -> bool:
        return _admin_role(request) in (AdminRole.CONTENT_MANAGER, AdminRole.SUPERADMIN)

    def is_visible(self, request: Request) -> bool:
        return self.is_accessible(request)

    async def after_model_change(self, data, model, is_created, request) -> None:
        packs.invalidate()  # offline packs are rebuilt with the new content

    async def after_model_delete(self, model, request) -> None:
        packs.invalidate()


class SuperadminView(ModelView):
    page_size = 50

    def is_accessible(self, request: Request) -> bool:
        return _admin_role(request) == AdminRole.SUPERADMIN

    def is_visible(self, request: Request) -> bool:
        return self.is_accessible(request)


class ClusterAdmin(ContentView, model=Cluster):
    name, name_plural, icon = "Кластер", "Кластеры ЦВЭ", "fa-solid fa-layer-group"
    column_list = [
        Cluster.id, Cluster.code, Cluster.title_ru, Cluster.title_tj, Cluster.duration_minutes, Cluster.order,
    ]
    column_sortable_list = [Cluster.order, Cluster.id]
    form_excluded_columns = [Cluster.created_at, Cluster.subject_links, Cluster.exam_tests]


class SubjectAdmin(ContentView, model=Subject):
    name, name_plural, icon = "Предмет", "Предметы", "fa-solid fa-book"
    column_list = [Subject.id, Subject.code, Subject.title_ru, Subject.title_tj, Subject.grade, Subject.order]
    column_searchable_list = [Subject.title_ru, Subject.title_tj, Subject.code]
    column_sortable_list = [Subject.grade, Subject.order, Subject.id]
    form_excluded_columns = [Subject.created_at, Subject.topics, Subject.cluster_links]


class ClusterSubjectAdmin(ContentView, model=ClusterSubject):
    name, name_plural, icon = "Субтест кластера", "Субтесты кластеров (A1–A4)", "fa-solid fa-link"
    column_list = [ClusterSubject.id, ClusterSubject.cluster, ClusterSubject.position, ClusterSubject.subject,
                   ClusterSubject.max_score, ClusterSubject.language_track]
    column_sortable_list = [ClusterSubject.cluster_id, ClusterSubject.position]


class TopicAdmin(ContentView, model=Topic):
    name, name_plural, icon = "Тема", "Разделы и темы", "fa-solid fa-sitemap"
    column_list = [Topic.id, Topic.title_ru, Topic.subject, Topic.parent_topic, Topic.order]
    column_searchable_list = [Topic.title_ru, Topic.title_tj]
    column_sortable_list = [Topic.subject_id, Topic.order, Topic.id]
    form_excluded_columns = [Topic.created_at, Topic.child_topics, Topic.lessons, Topic.questions]


class LessonAdmin(ContentView, model=Lesson):
    name, name_plural, icon = "Урок", "Уроки", "fa-solid fa-chalkboard"
    column_list = [Lesson.id, Lesson.title, Lesson.topic, Lesson.language, Lesson.order]
    column_searchable_list = [Lesson.title]
    column_sortable_list = [Lesson.topic_id, Lesson.order, Lesson.id]
    form_excluded_columns = [Lesson.created_at, Lesson.check_questions]


class QuestionAdmin(ContentView, model=Question):
    name, name_plural, icon = "Вопрос", "Вопросы", "fa-solid fa-circle-question"
    column_list = [
        Question.id, Question.question_type, Question.text, Question.topic, Question.exam_test, Question.source,
    ]
    column_formatters = {Question.text: lambda m, a: (m.text[:80] + "…") if len(m.text) > 80 else m.text}
    column_searchable_list = [Question.text]
    column_sortable_list = [Question.id, Question.topic_id, Question.exam_test_id]
    form_excluded_columns = [Question.created_at]
    form_args = {
        "options": {"description": 'JSON-массив вариантов, напр. ["2", "4", "6", "8"]'},
        "correct_option_index": {"description": "Для выбора ответа: индекс правильного варианта, с 0"},
        "correct_answer": {"description": 'Выбор: [1]; соответствие: [2, 0, 4, 1] (индексы вариантов для A–D); '
                                          'открытый: "125"'},
        "matching_left": {"description": 'Для соответствия: левый столбец A–D, JSON-массив'},
    }


class ExamTestAdmin(ContentView, model=ExamTest):
    name, name_plural, icon = "Тест ЦВЭ", "Тесты ЦВЭ (образцы и прошлые годы)", "fa-solid fa-file-signature"
    column_list = [ExamTest.id, ExamTest.title, ExamTest.cluster, ExamTest.year, ExamTest.duration_minutes,
                   ExamTest.is_published]
    column_sortable_list = [ExamTest.year, ExamTest.id]
    form_excluded_columns = [ExamTest.created_at, ExamTest.questions]


class AchievementAdmin(ContentView, model=Achievement):
    name, name_plural, icon = "Достижение", "Достижения", "fa-solid fa-medal"
    column_list = [Achievement.id, Achievement.code, Achievement.title_ru, Achievement.points_reward]
    form_excluded_columns = [Achievement.created_at]


class UserAdmin(SuperadminView, model=User):
    name, name_plural, icon = "Пользователь", "Пользователи", "fa-solid fa-users"
    can_create = False
    column_list = [User.id, User.name, User.email, User.phone, User.active_role, User.admin_role,
                   User.is_active, User.created_at, User.last_login_at]
    column_searchable_list = [User.email, User.name, User.phone]
    column_sortable_list = [User.id, User.created_at, User.last_login_at]
    column_details_exclude_list = [User.password_hash]
    # Blocking = unchecking is_active; admins are appointed via admin_role
    form_columns = [User.name, User.is_active, User.admin_role]


class AbiturientProfileAdmin(SuperadminView, model=AbiturientProfile):
    name, name_plural, icon = "Профиль абитуриента", "Профили абитуриентов", "fa-solid fa-user-graduate"
    can_create = False
    column_list = [AbiturientProfile.id, AbiturientProfile.user, AbiturientProfile.cluster,
                   AbiturientProfile.target_year, AbiturientProfile.region]


class SchoolProfileAdmin(SuperadminView, model=SchoolProfile):
    name, name_plural, icon = "Профиль школьника", "Профили школьников", "fa-solid fa-child"
    can_create = False
    column_list = [SchoolProfile.id, SchoolProfile.user, SchoolProfile.grade, SchoolProfile.school_name,
                   SchoolProfile.language_of_study]


class TestAttemptAdmin(SuperadminView, model=TestAttempt):
    name, name_plural, icon = "Попытка", "Попытки тестов", "fa-solid fa-list-check"
    can_create = can_edit = False
    column_list = [TestAttempt.id, TestAttempt.user, TestAttempt.test_type, TestAttempt.status,
                   TestAttempt.correct_count, TestAttempt.total_count, TestAttempt.mmt_score, TestAttempt.started_at]
    column_sortable_list = [TestAttempt.id, TestAttempt.started_at]


class StatsView(BaseView):
    name = "Статистика"
    icon = "fa-solid fa-chart-line"

    def is_accessible(self, request: Request) -> bool:
        return _admin_role(request) == AdminRole.SUPERADMIN

    def is_visible(self, request: Request) -> bool:
        return self.is_accessible(request)

    @expose("/stats", methods=["GET"])
    async def stats_page(self, request: Request):
        with SessionLocal() as db:
            stats = collect_stats(db)
        return await self.templates.TemplateResponse(request, "stats.html", context={"stats": stats})


def setup_admin(app: FastAPI, engine) -> Admin:
    admin = Admin(
        app,
        engine,
        base_url="/admin",
        title="EduApp — админ-панель",
        templates_dir=os.path.join(os.path.dirname(__file__), "templates"),
        authentication_backend=AdminAuth(secret_key=settings.SECRET_KEY),
    )
    for view in (
        StatsView, ClusterAdmin, SubjectAdmin, ClusterSubjectAdmin, TopicAdmin, LessonAdmin, QuestionAdmin,
        ExamTestAdmin,
        AchievementAdmin, UserAdmin, AbiturientProfileAdmin, SchoolProfileAdmin, TestAttemptAdmin,
    ):
        admin.add_view(view)
    return admin
