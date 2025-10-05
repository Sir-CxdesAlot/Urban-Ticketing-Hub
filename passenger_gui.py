import tkinter as tk
from tkinter import messagebox, simpledialog, scrolledtext, ttk
import requests
import json
import subprocess
import threading
import time

# Configuration
config = {
    "PassengerService": "http://localhost:8081",
    "TransportService": "http://localhost:8082",
    "TicketingService": "http://localhost:8083",
    "PaymentService": "http://localhost:8084",
    "NotificationService": "http://localhost:8085",
    "AdminService": "http://localhost:8086"
}

# Session state
session = {
    "passenger_logged_in": False,
    "passenger_token": None,
    "passenger_user": None,
    "passenger_email": None,
    "admin_logged_in": False,
    "admin_token": None,
    "admin_user": None,
    "admin_username": None
}

# API Helper
def api_call(url, method='GET', body=None, use_auth=False, auth_type='passenger'):
    headers = {'Content-Type': 'application/json'}
    if use_auth:
        token = session[f"{auth_type}_token"]
        if token:
            headers['Authorization'] = f"Bearer {token}"
    try:
        if body:
            response = requests.request(method, url, headers=headers, json=body, timeout=30)
        else:
            response = requests.request(method, url, headers=headers, timeout=30)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        raise Exception(str(e))

# UI Helper
def show_message(title, message, type='info'):
    if type == 'error':
        messagebox.showerror(title, message)
    elif type == 'warning':
        messagebox.showwarning(title, message)
    else:
        messagebox.showinfo(title, message)

def run_in_thread(func, *args):
    thread = threading.Thread(target=func, args=args, daemon=True)
    thread.start()

# =============================================================================
# PASSENGER TAB FUNCTIONS
# =============================================================================

def update_passenger_ui():
    if session['passenger_logged_in']:
        passenger_status_label.config(text=f"Logged in as: {session['passenger_user']['firstName']} {session['passenger_user']['lastName']} ({session['passenger_email']})")
        passenger_btn_register.config(state='disabled')
        passenger_btn_login.config(state='disabled', text="Logout", command=passenger_logout)
        passenger_btn_profile.config(state='normal')
        passenger_btn_routes.config(state='normal')
        passenger_btn_trips.config(state='normal')
        passenger_btn_purchase.config(state='normal')
        passenger_btn_my_tickets.config(state='normal')
    else:
        passenger_status_label.config(text="Not logged in")
        passenger_btn_register.config(state='normal')
        passenger_btn_login.config(state='normal', text="Login", command=passenger_login)
        passenger_btn_profile.config(state='disabled')
        passenger_btn_routes.config(state='normal')
        passenger_btn_trips.config(state='normal')
        passenger_btn_purchase.config(state='disabled')
        passenger_btn_my_tickets.config(state='disabled')

def passenger_register():
    reg_win = tk.Toplevel(root)
    reg_win.title("Register New Account")
    reg_win.geometry("300x300")

    tk.Label(reg_win, text="First Name:").pack()
    first_name = tk.Entry(reg_win)
    first_name.pack()

    tk.Label(reg_win, text="Last Name:").pack()
    last_name = tk.Entry(reg_win)
    last_name.pack()

    tk.Label(reg_win, text="Email:").pack()
    email = tk.Entry(reg_win)
    email.pack()

    tk.Label(reg_win, text="Phone:").pack()
    phone = tk.Entry(reg_win)
    phone.pack()

    tk.Label(reg_win, text="Password:").pack()
    password = tk.Entry(reg_win, show="*")
    password.pack()

    def submit():
        try:
            body = {
                "firstName": first_name.get(),
                "lastName": last_name.get(),
                "email": email.get(),
                "phone": phone.get(),
                "password": password.get()
            }
            response = api_call(f"{config['PassengerService']}/api/v1/passenger/register", "POST", body)
            show_message("Success", "Account created successfully! You can now log in.")
            reg_win.destroy()
        except Exception as e:
            show_message("Error", f"Registration failed: {e}", 'error')

    tk.Button(reg_win, text="Register", command=submit).pack()

def passenger_login():
    login_win = tk.Toplevel(root)
    login_win.title("Login")
    login_win.geometry("250x150")

    tk.Label(login_win, text="Email:").pack()
    email = tk.Entry(login_win)
    email.pack()

    tk.Label(login_win, text="Password:").pack()
    password = tk.Entry(login_win, show="*")
    password.pack()

    def submit():
        try:
            body = {
                "email": email.get(),
                "password": password.get()
            }
            response = api_call(f"{config['PassengerService']}/api/v1/passenger/login", "POST", body)
            session['passenger_logged_in'] = True
            session['passenger_token'] = response['token']
            session['passenger_user'] = response['user']
            session['passenger_email'] = email.get()
            show_message("Success", f"Login successful! Welcome, {response['user']['firstName']}!")
            login_win.destroy()
            update_passenger_ui()
        except Exception as e:
            show_message("Error", f"Login failed: {e}", 'error')

    tk.Button(login_win, text="Login", command=submit).pack()

def passenger_logout():
    session['passenger_logged_in'] = False
    session['passenger_token'] = None
    session['passenger_user'] = None
    session['passenger_email'] = None
    show_message("Success", "Logged out successfully")
    update_passenger_ui()

def passenger_show_profile():
    try:
        profile = api_call(f"{config['PassengerService']}/api/v1/passenger/profile", use_auth=True, auth_type='passenger')
        info = f"Name: {profile['firstName']} {profile['lastName']}\nEmail: {profile['email']}\nPhone: {profile['phone']}"
        show_message("Profile", info)
    except Exception as e:
        show_message("Error", f"Failed to load profile: {e}", 'error')

def passenger_show_routes():
    try:
        routes = api_call(f"{config['TransportService']}/api/v1/transport/routes")
        if not routes:
            show_message("Routes", "No routes available")
            return
        route_win = tk.Toplevel(root)
        route_win.title("Available Routes")
        route_win.geometry("600x400")
        text = scrolledtext.ScrolledText(route_win)
        text.pack(fill=tk.BOTH, expand=True)
        for route in routes:
            text.insert(tk.END, f"{route['name']}\nFrom: {route['startLocation']}\nTo: {route['endLocation']}\nType: {route['transportType']}\nPrice: N${route['basePrice']}\n")
            if route.get('intermediateStops'):
                text.insert(tk.END, f"Stops: {', '.join(route['intermediateStops'])}\n")
            text.insert(tk.END, "\n")
    except Exception as e:
        show_message("Error", f"Failed to load routes: {e}", 'error')

def passenger_show_trips():
    try:
        trips = api_call(f"{config['TransportService']}/api/v1/transport/trips")
        routes = api_call(f"{config['TransportService']}/api/v1/transport/routes")
        if not trips:
            show_message("Trips", "No trips scheduled")
            return
        trip_win = tk.Toplevel(root)
        trip_win.title("Scheduled Trips")
        trip_win.geometry("800x600")
        text = scrolledtext.ScrolledText(trip_win)
        text.pack(fill=tk.BOTH, expand=True)
        route_map = {route.get('_id', route.get('id', route.get('routeId', ''))): route for route in routes}
        grouped = {}
        for trip in trips:
            rid = trip.get('routeId', '')
            if rid not in grouped:
                grouped[rid] = []
            grouped[rid].append(trip)
        for rid, trips_list in grouped.items():
            route = route_map.get(rid)
            if route:
                text.insert(tk.END, f"{route['name']}\n{route['startLocation']} → {route['endLocation']}\nTransport: {route['transportType']} | Base Fare: N${route['basePrice']}\n\n")
            for trip in trips_list:
                status = trip.get('status', '')
                avail = f"{trip.get('availableSeats', 0)}/{trip.get('totalSeats', 0)}"
                text.insert(tk.END, f"Trip at {trip['departureTime']} - Arrival: {trip['arrivalTime']}\nSeats: {avail} | Status: {status}\n\n")
            text.insert(tk.END, "-"*50 + "\n")
    except Exception as e:
        show_message("Error", f"Failed to load trips: {e}", 'error')

def passenger_purchase_ticket():
    show_message("Purchase Ticket", "This feature requires selecting a route and trip. Please use the API or web interface for ticket purchases.\n\nSteps:\n1. Browse routes\n2. Check trip schedules\n3. Note IDs\n4. Use direct API calls")

def passenger_my_tickets():
    try:
        tickets = api_call(f"{config['PassengerService']}/api/v1/passenger/tickets", use_auth=True, auth_type='passenger')
        if not tickets:
            show_message("My Tickets", "You have no tickets yet")
            return
        ticket_win = tk.Toplevel(root)
        ticket_win.title("My Tickets")
        ticket_win.geometry("600x400")
        text = scrolledtext.ScrolledText(ticket_win)
        text.pack(fill=tk.BOTH, expand=True)
        for ticket in tickets:
            status = ticket.get('status', '')
            text.insert(tk.END, f"Ticket ID: {ticket['id']}\nType: {ticket.get('ticketType', '')}\nPrice: N${ticket.get('price', 0)}\nStatus: {status}\nPurchased: {ticket.get('purchaseDate', '')}\n\n")
    except Exception as e:
        show_message("Error", f"Failed to load tickets: {e}", 'error')

# =============================================================================
# ADMIN TAB FUNCTIONS
# =============================================================================

def update_admin_ui():
    if session['admin_logged_in']:
        admin_status_label.config(text=f"Logged in as: {session['admin_username']} ({session['admin_user']['role']})")
        admin_login_frame.pack_forget()
        admin_main_frame.pack(fill=tk.BOTH, expand=True)
    else:
        admin_status_label.config(text="Not logged in")
        admin_main_frame.pack_forget()
        admin_login_frame.pack(fill=tk.BOTH, expand=True)

def admin_login():
    username = admin_username_entry.get()
    password = admin_password_entry.get()
    
    try:
        body = {
            "username": username,
            "password": password
        }
        response = api_call(f"{config['AdminService']}/api/v1/admin/login", "POST", body)
        session['admin_logged_in'] = True
        session['admin_token'] = response['token']
        session['admin_user'] = response['admin']
        session['admin_username'] = username
        show_message("Success", f"Admin login successful! Welcome, {username}!")
        update_admin_ui()
    except Exception as e:
        show_message("Error", f"Admin login failed: {e}", 'error')

def admin_logout():
    session['admin_logged_in'] = False
    session['admin_token'] = None
    session['admin_user'] = None
    session['admin_username'] = None
    show_message("Success", "Admin logged out successfully")
    update_admin_ui()

def admin_show_dashboard():
    try:
        dashboard = api_call(f"{config['AdminService']}/api/v1/admin/dashboard", use_auth=True, auth_type='admin')
        info = f"System Overview:\n\nTotal Passengers: {dashboard['totalPassengers']}\nActive Routes: {dashboard['activeRoutes']}\nTickets Sold Today: {dashboard['ticketsSoldToday']}\nRevenue Today: N${dashboard['revenueToday']}\nActive Disruptions: {dashboard['activeDisruptions']}"
        show_message("Admin Dashboard", info)
    except Exception as e:
        show_message("Error", f"Failed to load dashboard: {e}", 'error')

def admin_show_routes():
    try:
        routes = api_call(f"{config['TransportService']}/api/v1/transport/routes")
        if not routes:
            show_message("Routes", "No routes in the system")
            return
        route_win = tk.Toplevel(root)
        route_win.title("All Routes")
        route_win.geometry("600x400")
        text = scrolledtext.ScrolledText(route_win)
        text.pack(fill=tk.BOTH, expand=True)
        for route in routes:
            status = "Active" if route.get('isActive', True) else "Inactive"
            text.insert(tk.END, f"{route['name']}\n{route['startLocation']} → {route['endLocation']}\nType: {route['transportType']} | Price: N${route['basePrice']}\nStatus: {status}\n\n")
    except Exception as e:
        show_message("Error", f"Failed to load routes: {e}", 'error')

def admin_create_route():
    create_win = tk.Toplevel(root)
    create_win.title("Create New Route")
    create_win.geometry("400x400")

    tk.Label(create_win, text="Route Name:").pack()
    name_entry = tk.Entry(create_win)
    name_entry.pack()

    tk.Label(create_win, text="Start Location:").pack()
    start_entry = tk.Entry(create_win)
    start_entry.pack()

    tk.Label(create_win, text="End Location:").pack()
    end_entry = tk.Entry(create_win)
    end_entry.pack()

    tk.Label(create_win, text="Transport Type (BUS/TRAIN):").pack()
    type_entry = tk.Entry(create_win)
    type_entry.pack()

    tk.Label(create_win, text="Base Price:").pack()
    price_entry = tk.Entry(create_win)
    price_entry.pack()

    def submit():
        try:
            body = {
                "name": name_entry.get(),
                "startLocation": start_entry.get(),
                "endLocation": end_entry.get(),
                "transportType": type_entry.get().upper(),
                "basePrice": float(price_entry.get()),
                "isActive": True
            }
            response = api_call(f"{config['TransportService']}/api/v1/transport/routes", "POST", body)
            show_message("Success", f"Route '{name_entry.get()}' created successfully!")
            create_win.destroy()
        except Exception as e:
            show_message("Error", f"Failed to create route: {e}", 'error')

    tk.Button(create_win, text="Create Route", command=submit).pack()

def admin_show_trips():
    try:
        trips = api_call(f"{config['TransportService']}/api/v1/transport/trips")
        routes = api_call(f"{config['TransportService']}/api/v1/transport/routes")
        if not trips:
            show_message("Trips", "No trips scheduled")
            return
        trip_win = tk.Toplevel(root)
        trip_win.title("All Trips")
        trip_win.geometry("800x600")
        text = scrolledtext.ScrolledText(trip_win)
        text.pack(fill=tk.BOTH, expand=True)
        route_map = {route.get('_id', route.get('id', route.get('routeId', ''))): route for route in routes}
        grouped = {}
        for trip in trips:
            rid = trip.get('routeId', '')
            if rid not in grouped:
                grouped[rid] = []
            grouped[rid].append(trip)
        for rid, trips_list in grouped.items():
            route = route_map.get(rid)
            if route:
                text.insert(tk.END, f"{route['name']}\n{route['startLocation']} → {route['endLocation']}\n\n")
            for trip in trips_list:
                status = trip.get('status', '')
                avail = f"{trip.get('availableSeats', 0)}/{trip.get('totalSeats', 0)}"
                text.insert(tk.END, f"Trip at {trip['departureTime']} - Arrival: {trip['arrivalTime']}\nSeats: {avail} | Status: {status}\n\n")
            text.insert(tk.END, "-"*50 + "\n")
    except Exception as e:
        show_message("Error", f"Failed to load trips: {e}", 'error')

def admin_create_trip():
    create_win = tk.Toplevel(root)
    create_win.title("Create New Trip")
    create_win.geometry("400x300")

    tk.Label(create_win, text="Route ID:").pack()
    route_entry = tk.Entry(create_win)
    route_entry.pack()

    tk.Label(create_win, text="Departure Time (HH:MM):").pack()
    dep_entry = tk.Entry(create_win)
    dep_entry.pack()

    tk.Label(create_win, text="Arrival Time (HH:MM):").pack()
    arr_entry = tk.Entry(create_win)
    arr_entry.pack()

    tk.Label(create_win, text="Total Seats:").pack()
    seats_entry = tk.Entry(create_win)
    seats_entry.pack()

    def submit():
        try:
            body = {
                "routeId": route_entry.get(),
                "departureTime": dep_entry.get(),
                "arrivalTime": arr_entry.get(),
                "availableSeats": int(seats_entry.get()),
                "totalSeats": int(seats_entry.get()),
                "status": "SCHEDULED"
            }
            response = api_call(f"{config['TransportService']}/api/v1/transport/trips", "POST", body)
            show_message("Success", "Trip created successfully!")
            create_win.destroy()
        except Exception as e:
            show_message("Error", f"Failed to create trip: {e}", 'error')

    tk.Button(create_win, text="Create Trip", command=submit).pack()

def admin_show_disruptions():
    try:
        disruptions = api_call(f"{config['AdminService']}/api/v1/admin/disruptions", use_auth=True, auth_type='admin')
        if not disruptions:
            show_message("Disruptions", "No active disruptions")
            return
        disp_win = tk.Toplevel(root)
        disp_win.title("Service Disruptions")
        disp_win.geometry("600x400")
        text = scrolledtext.ScrolledText(disp_win)
        text.pack(fill=tk.BOTH, expand=True)
        for disp in disruptions:
            text.insert(tk.END, f"{disp['title']}\n{disp['description']}\nType: {disp['type']}\nRoute ID: {disp['routeId']}\n\n")
    except Exception as e:
        show_message("Error", f"Failed to load disruptions: {e}", 'error')

def admin_create_disruption():
    create_win = tk.Toplevel(root)
    create_win.title("Create Service Disruption")
    create_win.geometry("400x400")

    tk.Label(create_win, text="Route ID:").pack()
    route_entry = tk.Entry(create_win)
    route_entry.pack()

    tk.Label(create_win, text="Type (DELAY/MAINTENANCE/CANCELLATION):").pack()
    type_entry = tk.Entry(create_win)
    type_entry.pack()

    tk.Label(create_win, text="Title:").pack()
    title_entry = tk.Entry(create_win)
    title_entry.pack()

    tk.Label(create_win, text="Description:").pack()
    desc_entry = tk.Entry(create_win)
    desc_entry.pack()

    def submit():
        try:
            body = {
                "routeId": route_entry.get(),
                "type": type_entry.get().upper(),
                "title": title_entry.get(),
                "description": desc_entry.get()
            }
            response = api_call(f"{config['AdminService']}/api/v1/admin/disruptions", "POST", body, use_auth=True, auth_type='admin')
            show_message("Success", "Service disruption created successfully!")
            create_win.destroy()
        except Exception as e:
            show_message("Error", f"Failed to create disruption: {e}", 'error')

    tk.Button(create_win, text="Create Disruption", command=submit).pack()

def admin_show_reports():
    try:
        report = api_call(f"{config['AdminService']}/api/v1/admin/reports/usage", use_auth=True, auth_type='admin')
        info = f"Usage Report:\n\nPeriod: {report['period']}\nTotal Tickets: {report['totalTickets']}\nTotal Revenue: N${report['totalRevenue']}\nAverage Price: N${report['averagePrice']}\nPeak Hour: {report['peakHour']}\nBusiest Route: {report['busiestRoute']}"
        show_message("Usage Report", info)
    except Exception as e:
        show_message("Error", f"Failed to generate report: {e}", 'error')

# =============================================================================
# MANAGEMENT TAB FUNCTIONS
# =============================================================================

def run_command(cmd, description, progress_var=None):
    def execute():
        try:
            if progress_var:
                progress_var.set(f"Running: {description}")
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=".")
            if result.returncode == 0:
                if progress_var:
                    progress_var.set(f"✅ {description} completed")
                show_message("Success", f"{description} completed successfully")
            else:
                if progress_var:
                    progress_var.set(f"❌ {description} failed")
                show_message("Error", f"{description} failed:\n{result.stderr}", 'error')
        except Exception as e:
            if progress_var:
                progress_var.set(f"❌ {description} error")
            show_message("Error", f"Failed to run {description}: {e}", 'error')
    
    run_in_thread(execute)

def management_setup():
    progress_var.set("Starting setup...")
    # Check Docker
    run_command("docker --version", "Docker check", progress_var)
    time.sleep(1)
    # Build services
    run_command("for /d %i in (admin_service notification_service payment_service ticketing_service transport_service passenger_service) do (cd %i && bal build)", "Building Ballerina services", progress_var)
    time.sleep(1)
    # Start services
    run_command("docker compose up -d --build", "Starting services", progress_var)

def management_start():
    progress_var.set("Starting services...")
    run_command("docker compose up -d", "Starting services", progress_var)

def management_status():
    status_win = tk.Toplevel(root)
    status_win.title("Service Status")
    status_win.geometry("600x500")
    
    text = scrolledtext.ScrolledText(status_win)
    text.pack(fill=tk.BOTH, expand=True)
    
    check_button = tk.Button(status_win, text="Check Status")
    check_button.pack()

    def check_status():
        check_button.config(state='disabled')
        try:
            if not text.winfo_exists():
                return
            text.delete(1.0, tk.END)
            text.insert(tk.END, "Checking service status...\n\n")
            
            # Services
            services = ["Passenger", "Transport", "Ticketing", "Payment", "Notification", "Admin"]
            for service in services:
                try:
                    url = f"{config[f'{service}Service']}/api/v1/{service.lower()}/health"
                    response = requests.get(url, timeout=3)
                    status = "🟢 UP" if response.status_code == 200 else "🔴 DOWN"
                except:
                    status = "🔴 DOWN"
                if not text.winfo_exists():
                    return
                text.insert(tk.END, f"{service} Service: {status} (Port {config[f'{service}Service'].split(':')[2]})\n")
            
            if not text.winfo_exists():
                return
            text.insert(tk.END, "\n")
            
            # Dependencies
            try:
                result = subprocess.run("docker exec ticketing-mongodb mongosh --quiet --eval 'db.runCommand({ ping: 1 }).ok'", shell=True, capture_output=True, text=True)
                mongo_status = "🟢 UP" if result.returncode == 0 else "🔴 DOWN"
            except:
                mongo_status = "🔴 DOWN"
            if not text.winfo_exists():
                return
            text.insert(tk.END, f"MongoDB: {mongo_status} (27017)\n")
            
            try:
                result = subprocess.run("docker exec ticketing-kafka kafka-broker-api-versions --bootstrap-server localhost:9092", shell=True, capture_output=True, text=True)
                kafka_status = "🟢 UP" if result.returncode == 0 else "🔴 DOWN"
            except:
                kafka_status = "🔴 DOWN"
            if not text.winfo_exists():
                return
            text.insert(tk.END, f"Kafka: {kafka_status} (9092)\n")
            
            # Containers
            if not text.winfo_exists():
                return
            text.insert(tk.END, "\nDocker Containers:\n")
            try:
                result = subprocess.run("docker compose ps", shell=True, capture_output=True, text=True)
                if not text.winfo_exists():
                    return
                text.insert(tk.END, result.stdout)
            except:
                if not text.winfo_exists():
                    return
                text.insert(tk.END, "Failed to get container status\n")
        finally:
            if check_button.winfo_exists():
                check_button.config(state='normal')
    
    check_button.config(command=lambda: run_in_thread(check_status))

def management_test_apis():
    progress_var.set("Testing APIs...")
    run_command("powershell -ExecutionPolicy Bypass -File test-apis.ps1", "API Testing", progress_var)

def management_initialize_data():
    progress_var.set("Initializing test data...")
    run_command("powershell -ExecutionPolicy Bypass -File initialize-test-data.ps1", "Data Initialization", progress_var)

# =============================================================================
# MAIN GUI SETUP
# =============================================================================

root = tk.Tk()
root.title("Windhoek Ticketing Platform - All-in-One GUI")
root.geometry("800x600")

notebook = ttk.Notebook(root)
notebook.pack(fill=tk.BOTH, expand=True)

# Passenger Tab
passenger_tab = ttk.Frame(notebook)
notebook.add(passenger_tab, text="Passenger")

passenger_status_label = tk.Label(passenger_tab, text="Not logged in", fg="green")
passenger_status_label.pack(pady=10)

passenger_btn_register = tk.Button(passenger_tab, text="Register", command=passenger_register)
passenger_btn_register.pack(pady=5)

passenger_btn_login = tk.Button(passenger_tab, text="Login", command=passenger_login)
passenger_btn_login.pack(pady=5)

passenger_btn_profile = tk.Button(passenger_tab, text="My Profile", command=passenger_show_profile, state='disabled')
passenger_btn_profile.pack(pady=5)

passenger_btn_routes = tk.Button(passenger_tab, text="Browse Routes", command=passenger_show_routes)
passenger_btn_routes.pack(pady=5)

passenger_btn_trips = tk.Button(passenger_tab, text="View Trip Schedules", command=passenger_show_trips)
passenger_btn_trips.pack(pady=5)

passenger_btn_purchase = tk.Button(passenger_tab, text="Purchase Ticket", command=passenger_purchase_ticket, state='disabled')
passenger_btn_purchase.pack(pady=5)

passenger_btn_my_tickets = tk.Button(passenger_tab, text="My Tickets", command=passenger_my_tickets, state='disabled')
passenger_btn_my_tickets.pack(pady=5)

# Admin Tab
admin_tab = ttk.Frame(notebook)
notebook.add(admin_tab, text="Admin")

admin_status_label = tk.Label(admin_tab, text="Not logged in", fg="blue")
admin_status_label.pack(pady=10)

admin_login_frame = ttk.Frame(admin_tab)
admin_main_frame = ttk.Frame(admin_tab)

# Login frame
tk.Label(admin_login_frame, text="Admin Login").pack(pady=10)
tk.Label(admin_login_frame, text="Username:").pack()
admin_username_entry = tk.Entry(admin_login_frame)
admin_username_entry.pack()
tk.Label(admin_login_frame, text="Password:").pack()
admin_password_entry = tk.Entry(admin_login_frame, show="*")
admin_password_entry.pack()
tk.Button(admin_login_frame, text="Login", command=admin_login).pack(pady=10)

# Main frame
tk.Button(admin_main_frame, text="Dashboard", command=admin_show_dashboard).pack(pady=5)
tk.Button(admin_main_frame, text="View Routes", command=admin_show_routes).pack(pady=5)
tk.Button(admin_main_frame, text="Create Route", command=admin_create_route).pack(pady=5)
tk.Button(admin_main_frame, text="View Trips", command=admin_show_trips).pack(pady=5)
tk.Button(admin_main_frame, text="Create Trip", command=admin_create_trip).pack(pady=5)
tk.Button(admin_main_frame, text="View Disruptions", command=admin_show_disruptions).pack(pady=5)
tk.Button(admin_main_frame, text="Create Disruption", command=admin_create_disruption).pack(pady=5)
tk.Button(admin_main_frame, text="Usage Reports", command=admin_show_reports).pack(pady=5)
tk.Button(admin_main_frame, text="Logout", command=admin_logout).pack(pady=10)

admin_login_frame.pack(fill=tk.BOTH, expand=True)

# Management Tab
management_tab = ttk.Frame(notebook)
notebook.add(management_tab, text="Management")

tk.Label(management_tab, text="Platform Management", font=("Arial", 14)).pack(pady=10)

progress_var = tk.StringVar()
progress_var.set("Ready")
progress_label = tk.Label(management_tab, textvariable=progress_var, fg="blue")
progress_label.pack(pady=5)

tk.Button(management_tab, text="Setup (Build & Start Services)", command=lambda: run_in_thread(management_setup)).pack(pady=5)
tk.Button(management_tab, text="Start Services", command=lambda: run_in_thread(management_start)).pack(pady=5)
tk.Button(management_tab, text="Check Status", command=management_status).pack(pady=5)
tk.Button(management_tab, text="Test APIs", command=lambda: run_in_thread(management_test_apis)).pack(pady=5)
tk.Button(management_tab, text="Initialize Test Data", command=lambda: run_in_thread(management_initialize_data)).pack(pady=5)

update_passenger_ui()
update_admin_ui()

root.mainloop()
