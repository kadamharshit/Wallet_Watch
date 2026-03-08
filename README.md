# WalletWatch 💰

WalletWatch is an **offline-first expense and budget tracking mobile application** built using **Flutter and Supabase**.

It allows users to track daily spending, manage budgets, and visualize expenses while continuing to work even without an internet connection.

The app demonstrates **mobile architecture with local-first storage and cloud synchronization**.

---

## ✨ Features

### 🔐 Authentication & Profile
- Secure login and logout using Supabase Auth
- Persistent login sessions
- Edit profile details (name, mobile, DOB)
- Read-only email
- Change password flow

---

### 💸 Expense Management
- Add expenses manually
- Categories:
  - Grocery
  - Travel
  - Food
  - Medical
  - Bills
  - Other
- Payment modes: **Cash / Online**
- Bank selection for online payments
- Edit and delete expenses
- Swipe gestures for edit/delete
- Group expenses by date (Today, Yesterday, Older)
- Filter expenses by **All / Cash / Online**

---

### 💰 Budget Management
- Add **Cash and Online budgets**
- Separate online budgets by bank
- Prevent duplicate bank names
- Edit and delete budgets
- Automatic total calculations
- Monthly budget summary
- Filter budgets by **All / Cash / Online**

---

### 🏠 Home Dashboard
- Monthly remaining balance
- Cash remaining vs Online remaining
- Budget usage indicators
- Pie chart visualization (Cash vs Online spending)
- Pull-to-refresh support
- Quick actions:
  - Add Expense
  - Add Budget

---

### 📊 Offline-First Data System
WalletWatch is designed with an **offline-first architecture**.

- Expenses are stored locally using **SQLite**
- Data is synced to **Supabase** when internet is available
- The app continues to function even without network connectivity
- Local database acts as the primary data source

---

### 📘 Informational Pages
- About Us
- How To Use guide

---

## 🛠️ Tech Stack

**Frontend**
- Flutter

**Backend**
- Supabase
  - Authentication
  - Cloud database

**Local Storage**
- SQLite

**Libraries**
- fl_chart → charts
- intl → date formatting

---


## 🏗️ Project Structure

```
lib/
 ├── features/
 │   ├── expense/
 │   │   ├── add_manual.dart
 │   │   ├── edit_expense.dart
 │   │   └── expense_tracker.dart
 │   ├── budget/
 │   ├── profile/
 │   └── home/
 │
 ├── services/
 │   └── expense_database.dart
 │
 ├── providers/
 │   └── theme_provider.dart
 │
 └── main.dart
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK installed
- Android Studio or VS Code
- Supabase project (optional for cloud sync)

---

### Run the app

```bash
flutter pub get
flutter run
```

---

## 📈 Future Improvements

- Expense search functionality
- Export expenses to CSV / Excel
- Spending insights and analytics
- Recurring expenses
- Notifications for budget limits

---

## 👨‍💻 Author

Developed by **Harshit Kadam**

This project was created as a **portfolio application demonstrating Flutter development, offline-first architecture, and backend integration using Supabase.**
