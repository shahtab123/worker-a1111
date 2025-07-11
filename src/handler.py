import time
import runpod
import requests
from requests.adapters import HTTPAdapter, Retry

LOCAL_URL = "http://127.0.0.1:3000/sdapi/v1"

automatic_session = requests.Session()
retries = Retry(total=10, backoff_factor=0.1, status_forcelist=[502, 503, 504])
automatic_session.mount('http://', HTTPAdapter(max_retries=retries))


# ---------------------------------------------------------------------------- #
#                              Automatic Functions                             #
# ---------------------------------------------------------------------------- #
def wait_for_service(url):
    """
    Check if the service is ready to receive requests.
    """
    retries = 0

    while True:
        try:
            requests.get(url, timeout=120)
            return
        except requests.exceptions.RequestException:
            retries += 1

            # Only log every 15 retries so the logs don't get spammed
            if retries % 15 == 0:
                print("Service not ready yet. Retrying...")
        except Exception as err:
            print("Error: ", err)

        time.sleep(0.2)


def run_inference(inference_request):
    """
    Run inference on a request.
    """
    endpoint = inference_request.get("endpoint", "txt2img")
    payload = inference_request.get("payload", {})
    
    # Handle different API endpoints
    if endpoint == "txt2img":
        response = automatic_session.post(
            url=f'{LOCAL_URL}/txt2img',
            json=payload,
            timeout=600
        )
    elif endpoint == "img2img":
        response = automatic_session.post(
            url=f'{LOCAL_URL}/img2img',
            json=payload,
            timeout=600
        )
    elif endpoint == "getModels":
        response = automatic_session.get(
            url=f'{LOCAL_URL}/sd-models',
            timeout=600
        )
    elif endpoint == "getLoras":
        response = automatic_session.get(
            url=f'{LOCAL_URL}/loras',
            timeout=600
        )
    elif endpoint == "getOptions":
        response = automatic_session.get(
            url=f'{LOCAL_URL}/options',
            timeout=600
        )
    elif endpoint == "setOptions":
        response = automatic_session.post(
            url=f'{LOCAL_URL}/options',
            json=payload,
            timeout=600
        )
    else:
        raise Exception(f"Endpoint '{endpoint}' not implemented")
    
    return response.json()


# ---------------------------------------------------------------------------- #
#                                RunPod Handler                                #
# ---------------------------------------------------------------------------- #
def handler(event):
    """
    This is the handler function that will be called by the serverless.
    """
    json = run_inference(event["input"])
    return json


if __name__ == "__main__":
    wait_for_service(url=f'{LOCAL_URL}/sd-models')
    print("WebUI API Service is ready. Starting RunPod Serverless...")
    runpod.serverless.start({"handler": handler})
