"""Pydantic models for request payload validation."""

from pydantic import BaseModel, Field


class EmailData(BaseModel):
    """Email fields that make up the body of an SQS message."""

    email_subject: str = Field(..., min_length=1)
    email_sender: str = Field(..., min_length=1)
    email_timestream: str = Field(..., min_length=1)
    email_content: str = Field(..., min_length=1)


class MessagePayload(BaseModel):
    """Top-level request body containing email data and an auth token."""

    data: EmailData
    token: str = Field(..., min_length=1)
