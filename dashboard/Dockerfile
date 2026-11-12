FROM python:3.11-slim
WORKDIR /app
RUN pip install --no-cache-dir streamlit==1.39.0 psycopg2-binary==2.9.10 pandas==2.2.3 plotly==5.24.1
EXPOSE 8501
# --server.runOnSave : la page se recharge dès que tu sauvegardes app.py
CMD ["streamlit", "run", "app.py", "--server.address=0.0.0.0", "--server.port=8501", "--server.runOnSave=true"]
