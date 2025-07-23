# api/schema.py
from pydantic import BaseModel
from typing import List

class ChurnInput(BaseModel):
    data: List[List[float]]
    columns: List[str]
