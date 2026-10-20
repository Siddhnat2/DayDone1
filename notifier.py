"""Local notifications. Android via JNI (QJniObject); desktop falls back to console."""
import sys


def _android_context():
    from PySide6.QtCore import QNativeInterface
    return QNativeInterface.QAndroidApplication.context()


def _android_notify(title: str, text: str, nid: int):
    from PySide6.QtCore import QJniObject
    J = QJniObject.fromString
    ctx = _android_context()
    svc = ctx.callObjectMethod("getSystemService",
                               "(Ljava/lang/String;)Ljava/lang/Object;", J("notification"))
    chan_id = "daydone_tasks"
    chan = QJniObject("android/app/NotificationChannel",
                      "(Ljava/lang/String;Ljava/lang/CharSequence;I)V",
                      J(chan_id), J("Task reminders"), 4)   # IMPORTANCE_HIGH
    svc.callMethod("createNotificationChannel",
                   "(Landroid/app/NotificationChannel;)V", chan)
    b = QJniObject("android/app/Notification$Builder",
                   "(Landroid/content/Context;Ljava/lang/String;)V", ctx, J(chan_id))
    b.callObjectMethod("setContentTitle",
                       "(Ljava/lang/CharSequence;)Landroid/app/Notification$Builder;", J(title))
    b.callObjectMethod("setContentText",
                       "(Ljava/lang/CharSequence;)Landroid/app/Notification$Builder;", J(text))
    b.callObjectMethod("setStyle",
                       "(Landroid/app/Notification$Style;)Landroid/app/Notification$Builder;",
                       QJniObject("android/app/Notification$BigTextStyle", "()V")
                       .callObjectMethod("bigText",
                                         "(Ljava/lang/CharSequence;)Landroid/app/Notification$BigTextStyle;",
                                         J(text)))
    b.callObjectMethod("setSmallIcon", "(I)Landroid/app/Notification$Builder;", 17301651)
    b.callObjectMethod("setAutoCancel", "(Z)Landroid/app/Notification$Builder;", True)
    notif = b.callObjectMethod("build", "()Landroid/app/Notification;")
    svc.callMethod("notify", "(ILandroid/app/Notification;)V", nid, notif)


def notify(title: str, text: str, nid: int = 1) -> bool:
    """Returns True if a native notification was posted."""
    if sys.platform == "android" or hasattr(sys, "getandroidapilevel"):
        try:
            _android_notify(title, text, nid)
            return True
        except Exception as e:          # keep the app alive no matter what
            print("notification failed:", e)
            return False
    print(f"[notification] {title} — {text}")
    return True  # console fallback counts as handled; avoids repeated desktop alerts
