from fastapi import FastAPI
from app.api.routes import router
from fastapi.staticfiles import StaticFiles

app = FastAPI()
app.mount("/processed", StaticFiles(directory="processed"), name="processed")
app.include_router(router)
