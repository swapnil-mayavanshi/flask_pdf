import os
import tempfile
import zipfile
from flask import Flask, render_template, request, send_file
import fitz  # PyMuPDF
import pandas as pd

app = Flask(__name__)
UPLOAD_FOLDER = tempfile.gettempdir()
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# --- CONFIGURATION ---
FONT_PATH = "times.ttf"  # You can ignore this if using built-in fonts
PREFERRED_SIZE = 11       # Font size for inserted text
EXPAND = 0                # Padding for redaction area
Y_SHIFT = 10              # Vertical offset for inserted text
UNDERLINE_OFFSET = 2      # How far below the text to draw underline
UNDERLINE_THICKNESS = 1   # Thickness of the underline
# ----------------------

def process_pdf(pdf_path, output_path, search_str, replace_str):
    doc = fitz.open(pdf_path)
    for page in doc:
        areas = page.search_for(search_str)
        expanded_areas = []

        for area in areas:
            expanded_area = fitz.Rect(
                area.x0 - EXPAND,
                area.y0 - EXPAND,
                area.x1 + EXPAND,
                area.y1 + EXPAND
            )
            page.add_redact_annot(expanded_area, fill=(1, 1, 1))  # White background
            expanded_areas.append((area, expanded_area))

        page.apply_redactions()

        for original_area, _ in expanded_areas:
            new_position = fitz.Point(original_area.x0, original_area.y0 + Y_SHIFT)
            page.insert_text(new_position, replace_str, fontsize=PREFERRED_SIZE, fontname="times-roman", color=(0, 0, 0))

            # Draw underline
            underline_y = new_position.y + UNDERLINE_OFFSET
            underline_start = fitz.Point(original_area.x0, underline_y)
            underline_end = fitz.Point(original_area.x0 + page.get_text_length(replace_str, fontname="times-roman", fontsize=PREFERRED_SIZE), underline_y)
            page.draw_line(underline_start, underline_end, color=(0, 0, 0), width=UNDERLINE_THICKNESS)

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
                return None

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

    return render_template('index_multi_simple.html')

if __name__ == '__main__':
    app.run(debug=True)
