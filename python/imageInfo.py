import argparse
import os
import json
import logging


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Get image information.")
    parser.add_argument("image_path", type=str, help="Path to the image file.", required=True)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("-g", "--get", help="Get key from image info file", action="store_true", dest="get")
    group.add_argument("-s", "--set", help="Set key in image info file", action="store_true", dest="set")
    parser.add_argument("-k", "--key", help="Key to get/set in image info file", type=str, required=True)
    parser.add_argument("-v", "--value", help="Value to set for the key (required with --set)", type=str, dest="value")
    
    args = parser.parse_args()
    if args.set and not args.value:
        logging.error("Value is required when using --set option.")
        exit(1)
    elif args.get and args.value:
        logging.warning("Value will be ignored when using --get option.")


    image_path = args.image_path
    if not os.path.exists(image_path):
        # Create the image info file if it doesn't exist
        try:
            with open(image_path, 'w') as f:
                json.dump({}, f, indent=4)
            logging.info(f"Created new image info file at {image_path}.")
        except Exception as e:
            logging.error(f"Error creating image info file: {e}")
            exit(1)
        
    try:
        with open(image_path, 'r') as f:
            image_info = json.load(f)
    except json.JSONDecodeError:
        logging.error(f"Error decoding JSON from image info file {image_path}.")
        exit(1)
        
    if args.get:
        if args.key in image_info:
            print(f"{image_info[args.key]}")
        else:
            print("")
            
    elif args.set:
        image_info[args.key] = args.value
        try:
            with open(image_path, 'w') as f:
                json.dump(image_info, f, indent=4)
            print(f"Set {args.key} to {args.value} in {image_path}.")
        except Exception as e:
            logging.error(f"Error writing to image info file: {e}")
            exit(1)
            
    