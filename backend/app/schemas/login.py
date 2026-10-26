"""Backward-compatible password login with an optional account context."""

from typing import Literal

from pydantic import BaseModel


LoginAccountType = Literal["customer", "sale", "owner", "admin"]


class LoginRequest(BaseModel):
    dinh_danh: str | None = None
    email: str | None = None
    password: str = ""
    # Omitted by older apps. Business modes are free; admin is still restricted.
    login_account_type: LoginAccountType | None = None
