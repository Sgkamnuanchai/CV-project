import tensorflow as tf
from tensorflow.keras.preprocessing import image
import numpy as np
from io import BytesIO
from PIL import Image
from flask import Flask, request, jsonify

# Load model
model = tf.keras.models.load_model("mobilenetv2_model_5.h5")

# Load class names from class.txt
with open("classes.txt", "r") as file:
    CLASS_NAMES = [line.strip() for line in file.readlines()]

# Prediction function
def predict_image(img: Image.Image):
    img = img.resize((224, 224))
    img_array = image.img_to_array(img)
    img_array = np.expand_dims(img_array, axis=0)
    img_array = img_array / 255.0

    # Inference
    predictions = model.predict(img_array)
    predicted_class = np.argmax(predictions[0])
    confidence = predictions[0][predicted_class]
    class_name = CLASS_NAMES[predicted_class]

    return {
        "class_id": int(predicted_class),
        "class_name": class_name,
        "confidence": float(confidence),
    }

# Google Cloud Function entry point
def predict(request):
    try:
        if request.method != "POST":
            return jsonify({"success": False, "error": "Only POST method is allowed"}), 405

        # Check if the file is present in the request
        if "file" not in request.files:
            raise ValueError("No file provided in the request")

        file = request.files["file"]
        if not file.content_type.startswith("image/"):
            raise ValueError("Uploaded file is not an image")

        # Read the image
        img = Image.open(BytesIO(file.read()))
        if img.mode != "RGB":
            img = img.convert("RGB")

        # Make prediction
        result = predict_image(img)

        return jsonify({"success": True, "result": result}), 200

    except ValueError as ve:
        return jsonify({"success": False, "error": str(ve)}), 400

    except Exception as e:
        return jsonify({"success": False, "error": f"Unexpected error: {str(e)}"}), 500
