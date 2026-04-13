/// User-facing Hebrew messages for Firebase Auth error codes.
String authErrorMessage(String? code) {
  switch (code) {
    case 'invalid-email':
      return 'כתובת האימייל אינה תקינה.';
    case 'weak-password':
      return 'הסיסמה חלשה מדי. נדרשים לפחות 6 תווים.';
    case 'email-already-in-use':
      return 'כתובת האימייל כבר רשומה במערכת.';
    case 'user-disabled':
      return 'החשבון חסום. פנה לתמיכה.';
    case 'user-not-found':
      return 'לא נמצא משתמש עם האימייל הזה.';
    case 'wrong-password':
      return 'סיסמה שגויה.';
    case 'invalid-credential':
      return 'פרטי ההתחברות שגויים.';
    case 'too-many-requests':
      return 'יותר מדי ניסיונות. נסה שוב מאוחר יותר.';
    case 'operation-not-allowed':
      return 'התחברות עם אימייל וסיסמה אינה מופעלת בפרויקט.';
    case 'network-request-failed':
      return 'בעיית רשת. בדוק את החיבור לאינטרנט.';
    default:
      return 'אירעה שגיאה בהתחברות. נסה שוב.';
  }
}
