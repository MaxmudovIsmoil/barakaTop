@extends('layouts.app')

@section('content')
    <div class="container">
        <div class="row">
            <div class="col-md-12">
                <button id="btn-nft-enable" onclick="initFirebaseMessagingRegistration()" class="btn btn-danger mb-1">Allow for Notification</button>

                <div class="card">
                    <div class="card-body">
                        @if (session('status'))
                            <div class="alert alert-success" role="alert">
                                {{ session('status') }}
                            </div>
                        @endif
                        <form action="{{ route('send.push-notification-test') }}" method="POST" class="js_myFrom row">
                            @csrf
                            <div class="form-group col-md-6">
                                <label>Title</label>
                                <input type="text" class="form-control" name="title" value="Yangi xabar">
                            </div>
                            <div class="form-group col-md-4">
                                <label>Data</label>
                                <select class="form-control js_event" name="event">
                                    <option value="accept_order">Buyurtmangiz tasdiqlandi</option>
                                    <option value="book_order">Buyurtmangiz tayyorlanyapti</option>
                                    <option value="start_order">Buyurtmangiz yo'lda</option>
                                    <option value="close_order">Buyurtmangiz yopildi</option>
                                    <option value="cancel_order">Buyurtmangiz bekor qilindi</option>
                                </select>
                            </div>
                            <div class="col-md-2" style="padding-top: 23px;">
                                <button type="button" class="js_send_btn btn btn-primary">Send Notification</button>
                            </div>
                        </form>
                    </div>
                </div>
            </div>
        </div>
    </div>

@endsection

@section('script')

    <script src="https://www.gstatic.com/firebasejs/8.3.0/firebase-app.js"></script>
    <script src="https://www.gstatic.com/firebasejs/8.3.0/firebase-messaging.js"></script>


    <script>
        var firebaseConfig = {
            apiKey: "AIzaSyBf4ZqENl_Noe6v9LrH7jCrK1vjWFfkAFA",
            authDomain: "laravel-firebase-app-9d9ca.firebaseapp.com",
            projectId: "laravel-firebase-app-9d9ca",
            storageBucket: "laravel-firebase-app-9d9ca.appspot.com",
            messagingSenderId: "324803386436",
            appId: "1:324803386436:web:374888956c99863b1b7011",
            // databaseURL: "https://Your_Project_ID.firebaseio.com",
            measurementId: "G-HYMMVELHT8"
        };

        firebase.initializeApp(firebaseConfig);
        const messaging = firebase.messaging();

        function initFirebaseMessagingRegistration() {
            messaging
                .requestPermission()
                .then(function () {
                    return messaging.getToken({
                        vapidKey: 'BJV2uA6LeIW98QhTzB3TJaw3Js09brgEt9IIGq6v5iPPQCnJOZcmtcKCpPyVNkyTLJg-V6aXDqYV744KuEguNEU'
                    })
                })
                .then(function(token) {
                    console.log(token);

                    $.ajaxSetup({
                        headers: {
                            'X-CSRF-TOKEN': $('meta[name="csrf-token"]').attr('content')
                        }
                    });

                    $.ajax({
                        url: '{{ route("save-push-notification-token") }}',
                        type: 'POST',
                        data: { token: token },
                        dataType: 'JSON',
                        success: function (response) {
                            alert('Token saved successfully.');
                        },
                        error: function (err) {
                            console.log('Token Error'+ err);
                        },
                    });

                }).catch(function (err) {
                console.log('User Chat Token Error'+ err);
            });
        }



        $(document).on('click', '.js_send_btn', function (e) {
            let form = $(this).closest('.js_myFrom')

            $.ajax({
                url: form.attr('action'),
                type: 'POST',
                data: form.serialize(),
                dataType: 'JSON',
                success: (response) => {
                    console.log('ajax response:', response)
                },
                error: (response) => {
                    console.log('error:', response)
                }
            })
        });


        messaging.onMessage(function(payload) {

            console.log('payload: ', payload)

            const noteTitle = payload.notification.title;
            const noteOptions = {
                // body: payload.notification.body,
                // icon: payload.notification.icon,
                data: payload.notification.data,
            };
            new Notification(noteTitle, noteOptions);
        });

    </script>

@endsection
