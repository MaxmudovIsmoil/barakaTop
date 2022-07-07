@extends('layouts.app')

@section('content')

     <div class="content-wrapper">
        <div class="content-body">
            <h3 class="text-center text-info position-absolute zindex-1" style="left: 38%; top: 4%">Foydalanuvchi ma'lumotlarini sozlash</h3>
            <div class="card">
                <div class="row mt-3 mb-2">
                    <div class="col-md-6">
                        <form action="{{ route('user.user_profile_update', [$user->id]) }}" id="js_user_profile_update_from" method="POST">
                            <div class="row ml-1">
                                @csrf
                                @method('PUT')
                                <div class="col-md-6 form-group">
                                    <label for="name">Ism familiya</label>
                                    <input type="text" name="name" class="form-control js_name" id="name" value="{{ $user->name }}" />
                                    <div class="invalid-feedback">Ism familiyani kiriting!</div>
                                </div>

                                <div class="col-md-6 form-group">
                                    <label for="phone">Telefon raqam</label>
                                    <input type="text" name="phone" class="form-control js_phone" id="phone" value="{{ $user->phone }}" />
                                    <div class="invalid-feedback">telefon raqamni kiriting!</div>
                                </div>

                                <div class="col-md-6 form-group">
                                    <label for="login">Login</label>
                                    <input type="text" name="username" class="form-control js_login" id="login" value="{{ $user->username }}" readonly />
                                    <div class="invalid-feedback">Loginni kiriting!</div>
                                </div>

                                <div class="col-md-6 form-group">
                                    <label for="parol">Parol</label>
                                    <input type="text" name="password" class="form-control js_password" id="parol" />
                                    <div class="invalid-feedback">Parolni kiriting!</div>
                                </div>

                                <div class="col-md-12 mt-1">
                                    <input type="submit" class="btn btn-outline-primary btn-block" name="saveBtn" value="Saqlash" />
                                </div>
                            </div>
                        </form>
                    </div>
                    <div class="col-md-6 user-actions">
                        <h5 class="text-center">Huquqlari</h5>
                        <ul class="list-group huquqlar-checkbox" style="height: 210px !important;">
                            @foreach($actions as $action)
                                @foreach($user->user_priv as $up)

                                    @if($action->id == $up->action_id)
                                        <li class="list-group-item">{{ $action->name }}</li>
                                    @endif

                                @endforeach
                            @endforeach
                        </ul>
                    </div>
                </div>
            </div>
        </div>
     </div>

@endsection


@section('script')

    <script>
        $(document).ready(function() {

            /** User profile update **/
            $('#js_user_profile_update_from').on('submit', function(e) {
                e.preventDefault()
                let form = $(this)
                let action = form.attr('action')

                let name = form.find('.js_name')
                let phone = form.find('.js_phone')
                let password = form.find('.js_password')

                $.ajax({
                    url: action,
                    type: "POST",
                    dataType: "json",
                    data: form.serialize(),
                    success: (response) => {

                        if(response.status) {
                            Swal.fire({
                                title: 'Saqlandi',
                                icon: 'success',
                                customClass: {confirmButton: 'd-none'},
                                buttonsStyling: false
                            });
                            // location.reload()
                        }
                        console.log(response)
                        if(typeof response.errors !== 'undefined') {
                            if (response.errors.name)
                                name.addClass('is-invalid')

                            if (response.errors.phone)
                                phone.addClass('is-invalid')

                            if(response.errors.password) {
                                password.addClass('is-invalid')
                                password.siblings('.invalid-feedback').html('Parolni kiriting')
                            }
                            if(response.errors.password == 'The password must be at least 6 characters.') {
                                password.addClass('is-invalid')
                                password.siblings('.invalid-feedback').html('Parol kamida 6 ta belgidan iborat bo\'lishi kerak')
                            }

                        }
                    },
                    error: (response) => {
                        console.log('error: ',response)
                    }
                })
            });

        })
    </script>

@endsection
