import Foundation

/// Hằng số + đoạn JS bơm vào Zalo Web. Tách riêng để dễ chỉnh khi Zalo đổi giao diện.
enum Zalo {
    static let chatURL = URL(string: "https://chat.zalo.me/")!
    static let bridgeName = "zaloBridge"               // tên message handler JS -> Swift
    static let refreshTaskID = "com.zalogiamsat.ios.refresh"
    static let maxSlots = 10

    /// Máy chủ đăng nhập (Google Apps Script Web App) — DÙNG CHUNG server với bản Android.
    /// Giao thức: GET ?phone=&key=&device=  -> {ok, reason, expiry, max};  ?action=ping&event=online để heartbeat.
    static let licenseEndpoint =
        "https://script.google.com/macros/s/AKfycbxd0yyA51axk9vWPGUZZWwcmocheCKkCJEmAx0ut7HPLDchBNcjoUQnHaFXx8bRmRZM/exec"

    /// Giả lập desktop để chat.zalo.me trả giao diện web đầy đủ (giống DESKTOP_UA bản Android).
    static let desktopUA =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
        "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

    /// Lấy số tin chưa đọc từ tiêu đề trang Zalo Web, ví dụ "(3) Zalo" -> 3.
    static func parseUnread(from title: String?) -> Int {
        guard let title, !title.isEmpty,
              let r = title.range(of: #"\((\d+)\)"#, options: .regularExpression)
        else { return 0 }
        return Int(title[r].dropFirst().dropLast()) ?? 0
    }

    /// Chặn API thông báo trình duyệt mà Zalo Web dùng -> lấy tên người gửi + nội dung,
    /// đẩy về Swift qua `window.webkit.messageHandlers.zaloBridge`.
    /// (Bản port của NOTIFY_HOOK_JS bên Android, đổi cầu nối AndroidBridge -> webkit.)
    static let notifyHookJS = #"""
    (function(){
      function send(t,b){
        try{
          window.webkit.messageHandlers.zaloBridge.postMessage({
            kind: 'notif', title: String(t==null?'':t), body: String(b==null?'':b)
          });
        }catch(e){}
      }
      try{
        function FakeNotif(title, opt){
          opt = opt || {};
          send(title, opt.body);
          return { close:function(){}, onclick:null, addEventListener:function(){}, removeEventListener:function(){} };
        }
        FakeNotif.requestPermission = function(cb){
          if(typeof cb === 'function') cb('granted');
          return Promise.resolve('granted');
        };
        try{ Object.defineProperty(FakeNotif,'permission',{get:function(){return 'granted';}}); }catch(e){}
        try{ window.Notification = FakeNotif; }catch(e){}
        try{
          if(window.ServiceWorkerRegistration && ServiceWorkerRegistration.prototype){
            var orig = ServiceWorkerRegistration.prototype.showNotification;
            ServiceWorkerRegistration.prototype.showNotification = function(title, opt){
              opt = opt || {}; send(title, opt.body);
              return orig ? orig.apply(this, arguments) : Promise.resolve();
            };
          }
        }catch(e){}
      }catch(e){}
    })();
    """#

    /// Giả lập trang luôn "visible" để Zalo không tạm dừng render/websocket khi WebView
    /// không nằm trên màn hình (đang chạy nền trong SessionManager).
    static let visibilityJS = #"""
    (function(){
      try{
        Object.defineProperty(document,'visibilityState',{configurable:true,get:function(){return 'visible';}});
        Object.defineProperty(document,'hidden',{configurable:true,get:function(){return false;}});
        document.addEventListener('visibilitychange', function(e){ e.stopImmediatePropagation(); }, true);
      }catch(e){}
    })();
    """#

    /// Báo số chưa đọc định kỳ về Swift (ổn định hơn KVO khi Zalo cập nhật tiêu đề thất thường).
    /// Ưu tiên đọc "(N) Zalo" ở tiêu đề; nếu tiêu đề không có số thì cộng badge trong danh sách
    /// hội thoại làm phương án dự phòng (đã lọc để tránh đếm nhầm).
    static let unreadReporterJS = #"""
    (function(){
      // (1) Nguồn ĐÁNG TIN NHẤT: tiêu đề tab "(N) Zalo" — đúng cách bản Android dùng, đã chạy ổn.
      function fromTitle(){
        try{ var m=(document.title||'').match(/\((\d+)\+?\)/); if(m) return parseInt(m[1],10)||0; }catch(e){}
        return -1;
      }
      function visible(el){ return !!(el && el.offsetParent !== null); }
      // (2) Dự phòng: cộng badge chưa đọc trên TỪNG hội thoại trong danh sách của Zalo Web.
      //     Zalo Web (React) đặt mỗi hội thoại trong phần tử class chứa "conv"; badge là phần tử
      //     LÁ chỉ chứa số. Lấy tối đa 1 badge/hội thoại để khỏi đếm trùng vùng nội dung tin.
      function fromConversationList(){
        try{
          var items=document.querySelectorAll('[class*="conv-item"],[class*="convItem"],[class*="conversation-item"],[class*="conversation"]');
          if(!items.length) return -1;
          var total=0, found=false;
          for(var i=0;i<items.length;i++){
            var it=items[i];
            if(!visible(it)) continue;
            var cand=it.querySelectorAll('span,div,b,i');
            for(var j=0;j<cand.length;j++){
              var el=cand[j];
              if(el.children.length!==0) continue;          // chỉ phần tử lá (badge), bỏ phần tử bọc
              var s=(el.textContent||'').trim();
              if(/^\d{1,3}\+?$/.test(s) && s.length<=4){
                total+=parseInt(s.replace('+',''),10)||0; found=true; break; // 1 badge / hội thoại
              }
            }
          }
          return found ? total : 0;
        }catch(e){ return -1; }
      }
      var last=-2;
      function tick(){
        var t=fromTitle();
        var n=(t>=0)?t:fromConversationList();
        if(n<0) n=0;
        if(n!==last){
          last=n;
          try{ window.webkit.messageHandlers.zaloBridge.postMessage({kind:'unread', count:n}); }catch(e){}
        }
      }
      try{ setInterval(tick, 4000); }catch(e){}
      tick();
    })();
    """#

    /// Bấm nút "Lấy mã mới" trên trang QR (nếu có) để mã luôn còn hạn trước khi chụp ảnh.
    /// Trả về 'REFRESHED' nếu vừa bấm, 'NONE' nếu không thấy nút. (Port REFRESH_QR_JS bên Android.)
    static let refreshQRJS = #"""
    (function(){
      try{
        var els=[].slice.call(document.querySelectorAll('a,button,div,span'));
        var t=els.filter(function(e){
          var s=(e.textContent||'').trim();
          return e.offsetParent!==null && s.length<20 && /lấy mã mới/i.test(s);
        });
        if(t.length){ t[0].click(); return 'REFRESHED'; }
        return 'NONE';
      }catch(e){ return 'ERR'; }
    })();
    """#
}
