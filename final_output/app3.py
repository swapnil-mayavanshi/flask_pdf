import os
import tempfile
import zipfile
from flask import Flask, render_template, request, send_file
import fitz  # PyMuPDF
import pandas as pd

app = Flask(__name__)
UPLOAD_FOLDER = tempfile.gettempdir()
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# --- FIXED CONFIGURATION ---
FONT_PATH = "times.ttf"  # You can ignore this if you use built-in fonts
PREFERRED_SIZE = 11
EXPAND = 0.5
Y_SHIFT = 10
# ---------------------------

def process_pdf(pdf_path, output_path, search_str, replace_str):
    doc = fitz.open(pdf_path)
    for page in doc:
        areas = page.search_for(search_str)
        for area in areas:
            page.add_redact_annot(area, fill=(1, 1, 1))  # Whiteout the original
        page.apply_redactions()
        for area in areas:
            new_position = fitz.Point(area.x0, area.y0 + Y_SHIFT)  # Adjusted position
            page.insert_text(new_position, replace_str, fontsize=PREFERRED_SIZE, fontname="times-roman", color=(0, 0, 0))
    doc.save(output_path)
    doc.close()
    return output_path

@app.route('/', methods=['GET', 'POST'])
def index():
    if request.method == 'POST':
        search_str = request.form['search_str']
        replace_str = request.form['replace_str']

        temp_dir = tempfile.mkdtemp()
        uploaded_file = request.files['data_file']
        file_ext = os.path.splitext(uploaded_file.filename)[1].lower()
        processed_files = []

        def process_one(data_path, filename):
            ext = os.path.splitext(filename)[1].lower()
            base = os.path.splitext(os.path.basename(filename))[0]
            if ext == '.pdf':
                outpath = os.path.join(temp_dir, f"{base}_replaced.pdf")
                process_pdf(data_path, outpath, search_str, replace_str)
                return outpath
            else:
                return None  # Ignore other types

        file_path = os.path.join(temp_dir, uploaded_file.filename)
        uploaded_file.save(file_path)
        out = process_one(file_path, uploaded_file.filename)
        if out:
            processed_files.append(out)

        zip_path = os.path.join(temp_dir, "replaced_files.zip")
        with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zout:
            for f in processed_files:
                zout.write(f, arcname=os.path.basename(f))

        return send_file(zip_path, as_attachment=True, download_name="replaced_files.zip")

    return render_template('index_multi_simple.html')  # Optional if using HTML

if __name__ == '__main__':
    app.run(debug=True)
