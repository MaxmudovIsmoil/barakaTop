<!DOCTYPE html>
<html class="loading dark-layout" lang="en" data-layout="dark-layout" data-textdirection="ltr">
<!-- BEGIN: Head-->
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width,initial-scale=1.0,user-scalable=0,minimal-ui">
    <meta name="description" content="barakatop">
    <meta name="keywords" content="">
    <title>Kirish oynasi</title>
    <link rel="apple-touch-icon" href="{{ asset('images/ico/apple-icon-120.png') }}">
    <link rel="shortcut icon" type="image/x-icon" href="{{ asset('images/ico/favicon.ico') }}">
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:ital,wght@0,300;0,400;0,500;0,600;1,400;1,500;1,600" rel="stylesheet">

    <!-- BEGIN: Theme CSS-->
    <link rel="stylesheet" type="text/css" href="{{ asset('css/bootstrap.min.css') }}">
    <link rel="stylesheet" type="text/css" href="{{ asset('css/bootstrap-extended.min.css') }}">
    <link rel="stylesheet" type="text/css" href="{{ asset('css/colors.min.css') }}">
    <link rel="stylesheet" type="text/css" href="{{ asset('css/components.min.css') }}">
    <link rel="stylesheet" type="text/css" href="{{ asset('css/themes/dark-layout.min.css') }}">
    <link rel="stylesheet" type="text/css" href="{{ asset('css/themes/bordered-layout.min.css') }}">

    <!-- BEGIN: Page CSS-->
    <link rel="stylesheet" type="text/css" href="{{ asset('css/plugins/forms/form-validation.css') }}">
    <link rel="stylesheet" type="text/css" href="{{ asset('css/pages/page-auth.min.css') }}">
    <!-- END: Page CSS-->

</head>
<!-- END: Head-->

<!-- BEGIN: Body-->
<body class="vertical-layout vertical-menu-modern blank-page navbar-floating footer-static" data-open="click" data-menu="vertical-menu-modern" data-col="blank-page">
<!-- BEGIN: Content-->
    <div class="app-content content">
        <div class="content-wrapper">
            <div class="content-body">
                <div class="auth-wrapper auth-v1 px-2">
                    <div class="auth-inner py-2">
                        <!-- Login v1 -->
                        <div class="card mb-0">
                            <div class="card-body">
                                <a href="javascript:void(0);" class="brand-logo">
                                    <h2 class="brand-text text-primary ml-1 mb-1">Baraka Top</h2>
                                </a>
                                <form class="auth-login-form mt-2" action="{{ route('login') }}" method="POST">
                                    @error('username')
                                        <p class="p-0 mt-1 mb-1 text-center text-danger font-weight-bold">{{'Login yoki parolda xatolik bor'}}</p>
                                    @enderror

                                    @csrf
                                    <div class="form-group">
                                        <label for="username" class="form-label">Login</label>
                                        <input
                                            type="text"
                                            class="form-control @error('username') is-invalid @enderror"
                                            id="username"
                                            name="username"
                                            tabindex="1"
                                            placeholder="admin"
                                            value="{{ old('username') }}"
                                        />

                                    </div>

                                    <div class="form-group">
                                        <div class="d-flex justify-content-between">
                                            <label for="login-password">Parol</label>
                                            @if (Route::has('password.request'))
                                                <a class="btn btn-link" href="{{ route('password.request') }}">
                                                    <small>Forgot Password?</small>
                                                </a>
                                            @endif
                                        </div>
                                        <div class="input-group input-group-merge form-password-toggle">
                                            <input
                                                type="password"
                                                class="form-control form-control-merge @error('password') is-invalid @enderror"
                                                id="login-password"
                                                name="password"
                                                tabindex="2"
                                                placeholder="&#xb7;&#xb7;&#xb7;&#xb7;&#xb7;&#xb7;&#xb7;&#xb7;&#xb7;&#xb7;&#xb7;&#xb7;"
                                                value="{{ old('password') }}"
                                            />
                                            <div class="input-group-append">
                                                <span class="input-group-text cursor-pointer"><i data-feather="eye"></i></span>
                                            </div>
                                        </div>
                                    </div>
                                    <div class="form-group">
                                        <div class="custom-control custom-checkbox">
                                            <input class="custom-control-input" type="checkbox" id="remember-me" tabindex="3" />
                                            <label class="custom-control-label" for="remember-me"> Eslab qol</label>
                                        </div>
                                    </div>
                                    <button class="btn btn-primary btn-block" tabindex="4">Kirish</button>
                                </form>

{{--                                <p class="text-center mt-2">--}}
{{--                                    <span>New on our platform?</span>--}}
{{--                                    <a href="page-auth-register-v1.html">--}}
{{--                                        <span>Create an account</span>--}}
{{--                                    </a>--}}
{{--                                </p>--}}
                            </div>
                            <!-- /Login v1 -->
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <!-- END: Content-->

    <!-- BEGIN: Vendor JS-->
    <script src="{{ asset('vendors/js/vendors.min.js') }}"></script>
    <!-- BEGIN Vendor JS-->

    <!-- BEGIN: Page Vendor JS-->
    <script src="{{ asset('vendors/js/forms/validation/jquery.validate.min.js') }}"></script>
    <!-- END: Page Vendor JS-->

    <!-- BEGIN: Theme JS-->
    <script src="{{ asset('js/core/app-menu.js') }}"></script>
    <script src="{{ asset('js/core/app.js') }}"></script>
    <!-- END: Theme JS-->


    <script>
        $(window).on('load',  function(){
            if (feather) {
                feather.replace({ width: 14, height: 14 });
            }
        })
    </script>
</body>
<!-- END: Body-->
</html>
