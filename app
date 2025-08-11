import fitz
import os
from flask import Flask, render_template, request, send_file
import uuid

app = Flask(__name__)
app.config['SECRET_KEY'] = 'a_very_secret_key_for_session'

UPLOAD_FOLDER = 'uploads'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

def replace_text_in_pdf(input_pdf_path, old_text, new_text):
    try:
        pdf_document = fitz.open(input_pdf_path)
        font_name = "Times-Roman"
        
        for page in pdf_document:
            text_instances = page.search_for(old_text)
            
            if text_instances:
                original_text_info = page.get_text("dict")['blocks']
                
                for rect in text_instances:
                    page.add_redact_annot(rect)
                page.apply_redactions()

                for rect in text_instances:
                    original_fontsize = 12
                    for block in original_text_info:
                        for line in block.get("lines", []):
                            for span in line.get("spans", []):
                                if old_text in span["text"]:
                                    original_fontsize = span["size"]
                                    break
                            else:
                                continue
                            break
                        else:
                            continue
                        break

                    font_params = {
                        'fontsize': original_fontsize,
                        'fontname': font_name
                    }
                    insert_point = fitz.Point(rect.x0, rect.y1 + -2.3)
                    page.insert_text(insert_point, new_text, **font_params)
        
        unique_filename = f"modified_{uuid.uuid4().hex}.pdf"
        output_pdf_path = os.path.join(UPLOAD_FOLDER, unique_filename)
        pdf_document.save(output_pdf_path)
        
        return output_pdf_path

    except Exception as e:
        print(f"An error occurred: {e}")
        return None

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/upload', methods=['POST'])
def upload_file():
    if 'pdf_file' not in request.files:
        return "No file part", 400
    
    file = request.files['pdf_file']
    old_text = request.form.get('old_text')
    new_text = request.form.get('new_text')
    
    if file.filename == '':
        return "No selected file", 400
    
    if file and old_text and new_text:
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], file.filename)
        file.save(filepath)
        
        modified_pdf_path = replace_text_in_pdf(filepath, old_text, new_text)
        
        os.remove(filepath)
        
        if modified_pdf_path:
            return send_file(
                modified_pdf_path,
                as_attachment=True,
                download_name="modified_document.pdf"
            )
        else:
            return "An error occurred during PDF processing.", 500

if __name__ == '__main__':
    app.run(debug=True)
