import json
import os
import sys
import requests

def main():
    print("==================================================")
    print("      Seva NGROK / Signaling URL Configurator     ")
    print("==================================================")
    print()

    # Find google-services.json to extract Firebase RTDB URL
    base_dir = os.path.dirname(os.path.abspath(__file__))
    json_path = os.path.abspath(os.path.join(base_dir, "..", "android", "app", "google-services.json"))
    
    if not os.path.exists(json_path):
        print(f"Error: Could not find google-services.json at: {json_path}")
        print("Please make sure you are running this from the correct workspace.")
        sys.exit(1)

    try:
        with open(json_path, "r") as f:
            config = json.load(f)
        firebase_url = config["project_info"]["firebase_url"]
    except Exception as e:
        print(f"Error reading google-services.json: {e}")
        firebase_url = input("Enter your Firebase RTDB URL manually (e.g. https://your-db.firebaseio.com): ").strip()

    if not firebase_url.endswith("/"):
        firebase_url += "/"

    print(f"Detected Firebase DB: {firebase_url}")
    print()
    
    # Prompt user for url
    url = input("Paste your ngrok HTTPS URL (e.g., https://4fce-106-51-171-32.ngrok-free.app): ").strip()
    if not url:
        print("Error: URL cannot be empty.")
        sys.exit(1)

    # Ensure clean url format
    if url.endswith("/"):
        url = url[:-1]

    # Save to Firebase Seva-v1/signaling_url
    target_url = f"{firebase_url}Seva-v1/signaling_url.json"
    print(f"Uploading to Firebase: {target_url}...")
    
    try:
        response = requests.put(target_url, json=url)
        if response.status_code == 200:
            print()
            print("==================================================")
            print("🎉 SUCCESS: URL successfully uploaded to Firebase!")
            print(f"Value set: {url}")
            print("Your Flutter clients will now automatically pull this URL.")
            print("==================================================")
        else:
            print(f"Failed to upload. HTTP Status: {response.status_code}")
            print(response.text)
    except Exception as e:
        print(f"Network error: {e}")

if __name__ == "__main__":
    main()
