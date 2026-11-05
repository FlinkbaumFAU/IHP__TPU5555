#!/usr/bin/env python3
import sys
import os
import subprocess

def parse_macros(files):
    macros = []
    for file in files:
        f = open(f"lef_out/{file}", "r")
        lines = f.readlines()
        is_macro = False
        for line in lines:
            if line.split(" ")[0] == "MACRO":
                is_macro = True
            if is_macro and line.split(" ")[0] == "END":
                macros.append(line)
                is_macro = False
            if is_macro:
                macros.append(line)
        f.close()
    return macros

def main():

    #Version check
    command = ["magic", "--version"]
    try:
        print("Checking magic version")
        print(f"{" ".join(command)}")
        result = subprocess.run(command, check=True,
                                stdout=subprocess.PIPE,  # Capture stdout
                                stderr=subprocess.PIPE,  # Capture stderr (optional)
                                text=True)
        maj = int(result.stdout.split(".")[0])
        mid = int(result.stdout.split(".")[1])
        min = int(result.stdout.split(".")[2])
        if maj < 8 or (maj == 8 and mid < 3) or (maj == 8 and mid == 3 and min < 617):
            print("Error: At least version 8.3.617 required")
            return

    except subprocess.CalledProcessError as e:
        print(f"Error executing command: {e}")
        return
    except Exception as e:
        print(f"An error occurred: {e}")
        return


    # Define the command and arguments
    pdk_root = os.getenv("PDK_ROOT")  # Get the PDK_ROOT environment variable
    command = [
        "magic",
        "-rcfile",
        f"{pdk_root}/ihp-sg13g2/libs.tech/magic/ihp-sg13g2.magicrc",
        "-nowindow",
        "-noconsole",
        "lef_out.tcl"
    ]

    # Run the command
    try:
        print("Run magic script for lef extraction")
        print(f"{" ".join(command)}")
        subprocess.run(command, check=True)
        print("Lef extraction successfull.")
    except subprocess.CalledProcessError as e:
        print(f"Error executing command: {e}")
        return
    except Exception as e:
        print(f"An error occurred: {e}")
        return


    print("Start accumulating lef files")
    files = os.listdir("lef_out")
    f = open(f"lef_out/{files[0]}", "r")
    lines = f.readlines()
    is_macro = False
    is_header = True
    macros = []
    header = []
    for line in lines:
        if line.split(" ")[0] == "MACRO":
            is_macro = True
            is_header = False
        if is_macro and line.split(" ")[0] == "END":
            macros.append(line)
            is_macro = False
        if is_header:
            header.append(line)
        if is_macro:
            macros.append(line)
    f.close()

    macros.extend(parse_macros(files[1:]))

    f = open("custom_stdcell.lef", "w")
    f.writelines(header)
    f.writelines(macros)
    f.write("END LIBRARY")

    f.close()
    print("Lef file successfully accumulated")

    #Cleanup
    for file in files:
        os.remove(f"lef_out/{file}")
    os.rmdir("lef_out")


if __name__ == "__main__":
    main()
