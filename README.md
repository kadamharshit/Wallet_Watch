# WalletWatch 💰

WalletWatch is an **offline-first expense and budget tracking mobile app** built using **Flutter and Supabase**.  
It helps users track daily expenses, manage cash and online budgets, and visualize spending patterns — all with a clean and intuitive UI.

---

## ✨ Features

### 🔐 Authentication & Profile
- Secure login and logout
- Edit profile details (name, mobile, DOB)
- Read-only email
- Change password flow
- Persistent login using Supabase Auth

---

### 💸 Expense Management
- Add expenses manually
- Categories: Grocery, Travel, Food, Medical, Bills, Other
- Payment modes: Cash / Online
- Bank selection for online payments
- Edit and delete expenses
- Swipe gestures for edit/delete
- Grouped by date with human-readable labels (Today, Yesterday)
- Filter expenses by **All / Cash / Online**

---

### 💰 Budget Management
- Add cash and online budgets
- Separate online budgets by bank
- Prevent duplicate bank names
- Edit and delete budgets
- Automatic total calculation
- Filter budgets by **All / Cash / Online**
- Monthly budget summary

---

### 🏠 Home Dashboard
- Total remaining balance for the month
- Cash remaining and online remaining
- Budget usage progress indicators
- Pie chart visualization (Cash vs Online)
- Pull-to-refresh support
- Quick actions: Add Expense / Add Budget

---

### 📊 Data & Sync
- Offline-first using SQLite
- Online sync with Supabase when connected
- Safe fallback to local data when offline

---

### 📘 Informational Pages
- About Us
- How To Use guide

---

## 🛠️ Tech Stack

- **Flutter** (UI & logic)
- **Supabase**
  - Authentication
  - Cloud database
- **SQLite** (offline storage)
- **fl_chart** (data visualization)
- **intl** (date formatting)

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK installed
- Android Studio / VS Code
- Supabase project (optional for cloud sync)

### Run the app
```bash
flutter pub get
flutter run
