# Designing and Controlling a Three-Axis Robotic Arm

Work Period: August 2026 – October 2026 

Project Team: Lias Bischof (KIT), Noah Sänger (University of Freiburg)

<br>

## Project Overview

The goal of this project is to design and build a fully functional three-axis robotic arm from scratch. The work covers mechanical design and manufacturing, the electronics for controls and the development of the controls software.

Specifically, the project involved:<br>
1\. Designing and building a three-axis robotic arm, from the CAD to a fully functional prototype.<br>
2\. Designing the mechanical components and integrating the actuators and control electronics.<br>
3\. Developing a controls software to calibrate and monitor the system.<br>
4\. Calibrating, testing, and optimizing the prototype for precision and reliability.<br>
5\. Using large language models to generate boilerplate code and support design tasks to accelerate the development

This project documentation should give the reader a quick overview of our work and focuses on the: (1.) **Controls**, (2.) **CAD** and (3.) **Electronics**, (4.) **Current limitations of the project** and (5.) **Learnings**

<br>

## Controls

Our custom-developed control software NOVA for MacOS, provides us a comprehensive control over the robotic arm.

The application allows us to:<br>
1\. Monitor the robots estimated state through a continuously updated 3D model.<br>
2\. Monitor the estimated position and orientation of each joint in 3D space.<br>
3\. Move one or all joints by specified angles.<br>
4\. Move the end-effector to a (reachable) position in 3D space using inverse kinematics.<br>
5\. Define waypoints through the terminal and execute them in sequence.<br>
6\. Monitor the waypoints as vectors in 3D space.<br>
7\. Track and manage visited, queued, and upcoming waypoints.<br>
8\. View the end-effectors estimated trajectory as a projection onto the XY plane.<br>
9\. Manage the connection with the MQTT broker and central controller.


### Interface and Commands

The interface provides users with information about the robots position and orientation, as well as its estimated trajectory. It also enables the user to control the robotic arm and manage the MQTT connection through an integrated terminal.

A simplified 3D model, built with RealityKit, is integrated to help users understand the robots state.
The model is continuously synchronized with the robots estimated position and orientation to reflect its current state.
Further, the waypoints entered by the user are visualized as vectors in 3d space, providing an overview of the robots next states.

The application also provides an interface for visited, queued, and upcoming waypoints. 
Further, the estimated path of the end-effector is visualized as a top-down projection onto the XY plane.
This helps the user to better understand the robots trajectory. 

The integrated terminal is designed to be intuitive and allow for a simple control of the robotic arm.
The commands provided to control and monitor the robot are listed below.

| Command | Description |
|---|---|
| `add <x> <y> <z> [none\|open\|close (default = none)] [index (default = tail)]` | Adds a waypoint to the path |
| `remove <index>` | Removes a pending waypoint from the path |
| `set <index> <x> <y> <z>` | Updates the coordinates of a waypoint |
| `set <index> <none\|open\|close>` | Updates the end-effector action for an pending waypoint |
| `swap <index> <index>` | Swaps the order of two waypoints |
| `move <x> <y> <z>` | Moves the end-effector to a specified position |
| `rotate <basis\|shoulder\|arm> <degrees>` | Rotates a single joint by given degrees |
| `rotate <basis> <shoulder> <arm>` | Rotates all three joints by given degrees |
| `orientation` | Returns the current joint angles |
| `position` | Returns the current joint positions |
| `start` | Begins or continues execution of the planned path |
| `stop` | Stops execution of the planned path and sends a hardware stop request (`machine/stop`) |
| `clear` | Removes all waypoints from the path |
| `reset` | Resets the path cursor |
| `connect [host (default = 127.0.0.1)] [port (default = 8003)]` / `disconnect` | Starts or ends the MQTT connection |


<table>
  <tr>
    <td width="50%" align="center">
      <img src="Protokoll/NOVA-Konsole.png" width="100%" alt="Terminal interface before calibration">
      <br>
      Terminal interface and 3D model before calibration
    </td>
    <td width="50%" align="center">
      <img src="Protokoll/NOVA-Kalibriert-Konsole.png" width="100%" alt="Terminal interface after calibration">
      <br>
      Terminal interface and 3D model after calibration
    </td>
  </tr>
</table>

<table>
  <tr>
    <td width="50%" align="center">
      <img src="Protokoll/NOVA-Pfad.png" width="100%" alt="Path interface before calibration">
      <br>
      Path interface and 3D model before calibration
    </td>
    <td width="50%" align="center">
      <img src="Protokoll/NOVA-Kalibriert-Pfad.png" width="100%" alt="Path interface after calibration">
      <br>
      Path interface and 3D model after calibration
    </td>
  </tr>
</table>

### Application Architecture

The application separates mqtt-communication, robot control, motion planning, and robot modeling into dedicated modules. 
The key modules of our application are outlined below.

| Path | Description |
|---|---|
| `controllers/mqtt-controller/` | Manages MQTT connection, monitors connection status, processes receipts, handles data transfers. |
| `controllers/machine-controller/` | Maintains the virtual robot model and manages the joint database. |
| `controllers/robot-controller/` | Handles calibration via MQTT and updates the virtual robot model. |
| `controllers/path-controller/` | Manages the movement path and target queue, estimates the robots trajectory and manages the path database. |
| `controllers/terminal-controller/` | Parses terminal commands and handles command executions. |
| `inverse-kinematics/` | Contains an analytical inverse kinematics solver. |
| `interface/2d-components/` | Contains the terminal interface and path interface. |
| `interface/3d-components/` | Contains the camera grid component and simple objects for the 3D scene. |


### MQTT Communication

NOVA communicates with the PICO controller via MQTT. 
The following topics are used to exchange robot-state, calibration-tasks and receipts:

| Topic | Purpose |
|---|---|
| `machine/state` | Requests and reports the current system status (`READY`, `BUSY` or `OFFLINE`) |
| `machine/calibration` | Transmits joint-angle corrections later used for calibration |
| `machine/receipt` | Confirms or rejects a request and links the response to its corresponding request using a UUID |

<br>

The simplified communication-protocol for CONNECTING, CALIBRATION, ROBOT-STATE-CHANGES and DISCONNECTING 
is described in the sequence-diagram below:

![MQTT communication sequence](Protokoll/MQTT-Sequenzdiagramm.png)

<br>

## CAD Model

The CAD model was designed in OnShape and Shapr3D. Critial components were analysed in SimScale to assess their structural integrity under expected loads.
The CAD views below show the robots mechanical design, including the complete assembly and more detailed views of the base, shoulder, and arm.

<table>
  <tr>
      <td width="20%" align="center" valign="top">
      <img src="Protokoll/CAD-Isometrisch.png" width="100%" alt="Left-side view of the complete assembly">
      <br>
      Complete CAD
    </td>
    <td width="20%" align="center" valign="top">
      <img src="Protokoll/CAD-Links.png" width="100%" alt="Left-side view of the complete assembly">
      <br>
      Complete CAD (Left)
    </td>
    <td width="20%" align="center" valign="top">
      <img src="Protokoll/CAD-Rechts.png" width="100%" alt="Right-side view of the complete assembly">
      <br>
      Complete CAD (Right)
    </td>
        <td width="20%" align="center" valign="top">
      <img src="Protokoll/CAD-Basis-Schnitt.png" width="100%" alt="Cross-sectional view of the base assembly">
      <br>
      Base (Cross-sectional)
    </td>
    <td width="20%" align="center" valign="top">
      <img src="Protokoll/CAD-Basis+Schulter.png" width="100%" alt="Base and shoulder assembly">
      <br>
      Base and Shoulder
    </td>
  </tr>
  <tr>
    <td width="20%" align="center" valign="top">
      <img src="Protokoll/CAD-Schulter-Schnitt.png" width="100%" alt="Cross-sectional view of the shoulder assembly">
      <br>
      Shoulder (Cross-sectional)
    </td>
    <td width="20%" align="center" valign="top">
      <img src="Protokoll/CAD-Schulter-Links.png" width="100%" alt="Left-side view of the shoulder assembly">
      <br>
      Shoulder (Left)
    </td>
    <td width="20%" align="center" valign="top">
      <img src="Protokoll/CAD-Schulter-Rechts.png" width="100%" alt="Right-side view of the shoulder assembly">
      <br>
       Shoulder (Right)
    </td>
    <td width="20%" align="center" valign="top">
      <img src="Protokoll/CAD-Arm-Oben.png" width="100%" alt="Top view of the arm assembly">
      <br>
      Arm (Top)
    </td>
    <td width="20%" align="center" valign="top">
      <img src="Protokoll/CAD-Arm-Schnitt.png" width="100%" alt="Cross-sectional view of the arm assembly">
      <br>
      Arm (Cross-sectional)
    </td>
    <td width="20%"></td>
  </tr>
</table>

<br>

## Electronics

The electronics to control the robot consist of an RP2040 PICO controller, four DM556 stepper motor drivers, four two-phase stepper motors and a 36V-10A power supply. 
Each driver controls a single motor, allowing all joints to be moved at once.
The wiring-diagram of our system is shown below.

![Elektronik](Protokoll/Elektronik.png)

The sequence diagram below shows how exactly calibration is processed. 
If the PICO controller receives a calibration command via MQTT, it first converts the given calibration angles into motor steps.
The controller then sends pulse and direction signals to the three joint drivers in parallel. 
Once all pulse sequences are complete, the PICO controller publishes a receipt via MQTT, reporting that the task is completed.
A receipt only confirms the generation of pulses. It does not verify that the motor has reached the intended position, 
as stalls or missed steps can occur.

![MQTT communication sequence](Protokoll/Kalibrierung-Sequenzdiagramm.png)

To simplify the architecture of our prototype we implemented a host-side C++ bridge to exchange data with the PICO controller via USB. The controller firmware then generates the motor pulses and sends MQTT events back through the bridge.


### Motor Channels and GPIO Assignment

The bridge-channels, GPIO-pins (STEP/DIR) and pulses per joint revolution for base-, shoulder-, arm- and end-effector motor are depicted below.

| Bridge-Channel | Function | STEP | DIR | Pulses per joint revolution |
|---|---|---|---|---|
| 1 | Base | GP0 | GP1 | 1,600 |
| 2 | Shoulder | GP2 | GP3 | 16,000 |
| 3 | Arm | GP6 | GP7 | 1,600 |
| 4 | End-Effector | GP4 | GP5 | +80 pulses to open, −80 to close. |


### Power and Driver Interface

To control the motors, the PICO controller sends step and direction signals to the DM556 stepper motor drivers, which regulate the current supplied to the motors. The drivers are powered by the 36V-10A DC power supply. The power-supply must not be connected directly to controller logic or GPIO pins. Driver current settings are configured to suit the connected motors.


### USB Communication and Completion

The bridge software was developed with the assistance of AI agents and improved by our team. Each USB message is one JSON object. Before connecting to MQTT, the bridge sends a ping to the controller and waits for a response.

<br>

## Repository Structure and Setup

| Location | Contents |
|---|---|
| Nova Frontend/ | macOS application, Xcode project and resolved Swift packages. |
| Nova Backend:Bridge/ | C++ bridge, shared protocol, broker configuration and startup script. |
| Nova Backend:Bridge/firmware/ | PICO firmware source. |
| Nova Backend:Bridge/tests/ | Protocol, simulated firmware, MQTT contract and integration tests. |
| CAD/Assets/ | Motor, gearbox, bearing, gripper and other component assets. |
| CAD/CAD Modell:SHAPR/ | Native Shapr3D assembly. |
| CAD/Drucke:STEP/ | Individual mechanical parts in STEP format. |
| Protokoll/ | CAD views, screenshots, editable diagrams and driver manual. |

### Build Requirements and Current Setup Gaps

The frontend project is Nova Frontend/Nova.xcodeproj. Its configured macOS deployment target is 26.2. It uses SwiftUI, RealityKit and MQTTNIO, with MQTTNIO 2.13.0 recorded in Package.resolved.

The bridge requires a C++17-capable compiler, libmosquitto and cJSON. Firmware compilation requires the Pico SDK, cJSON, access to the shared protocol.hpp header and USB standard I/O configuration.

The startup script calls `make` before starting Mosquitto and the bridge. The repository now includes `/home/runner/work/robotic-arm/robotic-arm/Nova Backend:Bridge/Makefile` with targets for `robot_bridge` and the backend test executables (`make`, `make test`, `make clean`). Firmware flashing still requires a Pico SDK-based workflow in addition to these host-side targets.

Once the bridge binary and flashed firmware are available, the bridge accepts --broker HOST, --mqtt-port PORT and --pico-port DEVICE. Without an explicit device, it searches for a unique /dev/cu.usbmodem* or /dev/ttyACM* port.

### Coordinates, Angles and Stored State

The model uses Y as the vertical axis and X–Z as the ground plane. The top-down path display therefore uses X–Z, clarifying the XY wording in the earlier overview.

Terminal rotate commands specify relative changes in degrees. Internal angles and MQTT calibration arrays use radians. Shoulder and arm angles describe each link's elevation relative to the horizontal.

Fallback lengths are 5.0 for the base, 15.0 for the shoulder and 10.0 for the arm. The code does not assign physical units to these values. Link lengths and input coordinates must use the same scale and match the real assembly.

The inverse kinematics solver checks link-length reachability and considers the available circle-intersection solutions, choosing the smallest combined shoulder/arm angular change. It does not perform full collision checking or accept an independently specified gripper orientation.

Joint state and waypoints are saved as JSON in the application's Application Support location: joint.basis.json, joint.shoulder.json, joint.arm.json and path.json. Missing or unreadable files trigger fallback values. Restoring saved state does not establish the physical pose after manual movement or a power cycle.

### Included Tests

| Source | Behaviour covered by the test code |
|---|---|
| test_protocol.cpp | Angle conversion, gripper mapping, JSON validation and limits. |
| test_firmware.cpp | Simulated pulse counts, stop handling, USB loss and malformed input. |
| test_mqtt_contract.cpp | Request IDs, state requests, busy rejection, receipts and retained commands. |
| test_bridge.cpp | Test broker and simulated PICO via pseudo-terminal, including USB disconnection. |

These are software tests, rather than measurements of payload, repeatability, motor temperature or electrical signal quality.

<br>

## Current Limitations and Further Documentation
| Direction | Event | Description |
|---|---|---|
| Pico → Bridge | boot | Firmware is booted up |
| Bridge → Pico | ping | Checks if the PICO is responding |
| Pico → Bridge | ready | Responds to the ping |
| Bridge → Pico | move | Starts a rotation on 1-4 motor channels |
| Pico → Bridge | busy | Rotation has started |
| Pico → Bridge | progress | Progress of rotation |
| Bridge → Pico | stop | Stops the rotation  |
| Pico → Bridge | stopped | Rotation has been stopped |
| Pico → Bridge | error | Reports that an error occurred |


- **Open-loop position:** No encoder feedback or automatic homing is implemented. Missed steps, backlash and structural deflection can separate the estimated pose from the physical pose.
- **Frontend stop:** The terminal stop command now cancels frontend waypoint execution and publishes `machine/stop`. Stopping still depends on broker/USB connectivity and firmware response time.
- **Gripper actions:** Waypoint execution now sends `open`/`close` actions to `machine/gripper` after reaching each target.
- **Interrupted moves:** The bridge reports executed pulse counts, but the frontend receipt model does not use them to reconstruct partial movement. Physical and estimated state must be reconciled after interruption.
- **Timeouts:** Frontend command requests now use a 120 s timeout to match the bridge execution window for active motions.
- **Trajectory preview:** The preview uses model joint speeds, rather than motor feedback or an exact simulation of the firmware scheduler.
- **Hardware revisions:** The electronics drawing labels motors as NEMA 17, while CAD assets include a NEMA 23 model. The older LaTeX draft describes a different controller/gripper configuration. Exact installed parts and driver settings still need an authoritative hardware list.
- **Physical validation:** Checked-in source files do not establish measured repeatability, payload capacity or thermal performance.
## Current Limitations

The current implementation of our project has the following limitations:

- **Open-loop position:** No encoder feedback or automatic homing is implemented. The control software estimates the prototype position and orientation from the commanded movements rather than measuring them.
- **End-Effector actions:** The end-effector has not yet been implemented in the prototype and end-effector actions (OPEN/CLOSE/NONE) aren't sent to the PICO controller.
- **Forward kinematics:** The path preview uses model joint speeds, rather than motor feedback or an exact simulation of the firmware scheduler.
- **Synchronization**: If another client calibrates the robot, its status is updated across all connected devices. But the change to the robots position is not synchronized yet.


## Learnings

Throughout the project, we encountered challenges in CAD, manufacturing, and programming. 
Solving these problems taught us how to apply the knowledge we gained in university, 
analyse real problems in electrical, mechanical and software engineering and develop solutions to adress them.
Additionally, the project strengthened our technical knowledge and problem-solving skills in mechatronics
and gave us practical insights into product development. 

The list underneath shows some of the knowledge and skills we gained throughout this project: 

1\. CAD: Learned to design mechanical modules and assemble them using OnShape and Shapr3D<br>
2\. Tolerances: Selecting suitable tolerances for printed parts, mechanical parts, actuator seats and bearing seats.<br>
3\. CAE: Used SimScale to evaluate structural integrity of critical parts.<br>
4\. 3D printing: Choosing suitable filament materials, layer orientation, wall thickness and infill settings.<br>
5\. Transmissions: Integrating transmissions and designing a belt drive to get the required joint torque.<br>
6\. Application architecture: Applied software design principles like modularity to build a maintainable controls application.<br>
7\. MQTT communication: Learned data transfer, receipts, monitoring and connection management via MQTT.<br>
8\. Data management: Learned data management using JSONDecoder and JSONEncoder.<br>
9\. Inverse kinematics: Applied learnings from linear algebra and optimization to develop an inverse kinematics solver.<br>
10\. Forward kinematics: Used physical parameters such as the actuators angular velocity to model the robots trajectory over time.<br>
11\. Electronics: Calculated the systems electrical requirements and selected suitable electronic components.<br>
12\. Circuit design: Designed a circuit schematic to define electrical connections and wiring.<br>
13\. AI: Learned how to guide AI agents to generate boilerplate code and speed up the overall development process.
