import enum
from typing import Type

from sqlalchemy import Enum as SAEnum


def str_enum(enum_cls: Type[enum.Enum], length: int = 32) -> SAEnum:
    """Store enum values as plain VARCHAR (portable across PostgreSQL/SQLite, easy migrations)."""
    return SAEnum(
        enum_cls,
        native_enum=False,
        length=length,
        values_callable=lambda e: [m.value for m in e],
        validate_strings=True,
    )
