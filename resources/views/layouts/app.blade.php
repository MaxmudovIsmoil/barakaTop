<!DOCTYPE html>

<html class="loading dark-layout" lang="en" data-layout="dark-layout" data-textdirection="ltr">
<!-- BEGIN: Head-->
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width,initial-scale=1.0,user-scalable=0,minimal-ui">
    <meta name="description" content="Vuexy admin is super flexible, powerful, clean &amp; modern responsive bootstrap 4 admin template with unlimited possibilities.">
    <meta name="keywords" content="admin template, Vuexy admin template, dashboard template, flat admin template, responsive admin template, web app">
    <meta name="author" content="PIXINVENT">
    <title>Admin page</title>
    <meta name="csrf-token" content="{{ csrf_token() }}">

    <link rel="apple-touch-icon" href="{{ asset('images/ico/apple-icon-120.png') }}">
    <link rel="shortcut icon" type="image/x-icon" href="{{ asset('images/ico/favicon.ico') }}">
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:ital,wght@0,300;0,400;0,500;0,600;1,400;1,500;1,600" rel="stylesheet">

    <!-- BEGIN: Vendor CSS-->
    <link rel="stylesheet" type="text/css" href="{{ asset('vendors/css/vendors.min.css') }}">
    <!-- END: Vendor CSS-->
    <link rel="stylesheet" type="text/css" href="{{ asset('vendors/css/charts/apexcharts.css') }}">

    <link rel="stylesheet" type="text/css" href="{{ asset('vendors/css/forms/select/select2.min.css') }}">

    <link rel="stylesheet" type="text/css" href="{{ asset('vendors/css/extensions/toastr.min.css') }}">
    <link rel="stylesheet" type="text/css" href="{{ asset('vendors/css/tables/datatable/dataTables.bootstrap4.min.css') }}">
    <link rel="stylesheet" type="text/css" href="{{ asset('vendors/css/tables/datatable/responsive.bootstrap4.min.css') }}">
    <link rel="stylesheet" type="text/css" href="{{ asset('vendors/css/tables/datatable/buttons.bootstrap4.min.css') }}">
    <!-- END: Vendor CSS-->
    <!-- BEGIN: Theme CSS-->
    <link rel="stylesheet" type="text/css" href="{{ asset('css/bootstrap.min.css') }}">
    <link rel="stylesheet" type="text/css" href="{{ asset('css/bootstrap-extended.min.css') }}">
    <link rel="stylesheet" type="text/css" href="{{ asset('css/colors.min.css') }}">
    <link rel="stylesheet" type="text/css" href="{{ asset('css/components.min.css') }}">
    <link rel="stylesheet" type="text/css" href="{{ asset('css/themes/dark-layout.min.css') }}">
    <link rel="stylesheet" type="text/css" href="{{ asset('css/themes/bordered-layout.min.css') }}">
    <link rel="stylesheet" type="text/css" href="{{ asset('css/themes/semi-dark-layout.min.css') }}">
    <link rel="stylesheet" type="text/css" href="{{ asset('fonts/font-awesome/css/font-awesome.min.css') }}">
    <link rel="stylesheet" type="text/css" href="{{ asset('css/fancybox.min.css') }}">

    <link rel="stylesheet" type="text/css" href="{{ asset("css/core/menu/menu-types/horizontal-menu.css") }}">

    <link rel="stylesheet" type="text/css" href="{{ asset('css/plugins/charts/chart-apex.min.css') }}">

    <link rel="stylesheet" type="text/css" href="{{ asset('vendors/css/pickers/flatpickr/flatpickr.min.css') }}">

    <link rel="stylesheet" type="text/css" href="{{ asset('css/core/menu/menu-types/vertical-menu.css') }}">
    <link rel="stylesheet" type="text/css" href="{{ asset('css/plugins/forms/pickers/form-flat-pickr.css') }}">
    <link rel="stylesheet" type="text/css" href="{{ asset('css/plugins/forms/pickers/form-pickadate.css') }}">
    <link rel="stylesheet" type="text/css" href="{{ asset('css/pages/app-ecommerce.css') }}">
    <link rel="stylesheet" type="text/css" href="{{ asset('css/plugins/extensions/ext-component-toastr.css') }}">

    <link rel="stylesheet" type="text/css" href="{{ asset('css/plugins/extensions/ext-component-sweet-alerts.css') }}">

    <link rel="stylesheet" type="text/css" href="{{ asset('file_uploaded/image-uploader.css') }}">
    <!-- BEGIN: Custom CSS-->
    <link rel="stylesheet" type="text/css" href="{{ asset('css/style.css') }}">
    <!-- END: Custom CSS-->
    <link rel="stylesheet" href="{{ asset('css/main.css') }}">

</head>
<!-- END: Head-->

<!-- BEGIN: Body-->
<body class="horizontal-layout horizontal-menu  navbar-floating footer-static" data-open="hover" data-menu="horizontal-menu" data-col="">

<!-- BEGIN: Header-->
<nav class="header-navbar navbar-expand-md navbar navbar-fixed navbar-shadow navbar-brand-center" data-nav="brand-center">
    <div class="navbar-container d-flex content">
        <div class="bookmark-wrapper d-flex align-items-center mr-3">
            <h2 class="brand-text mb-0"><a href="{{ route('dashboard') }}" class="nav-link">BarakaTop</a> </h2>
        </div>

        <div class="nav navbar-nav">

            <!-- menu -->
            <ul class="nav navbar-nav">

                @if(\Helper::checkUserActions(601))
                    <li class="nav-item">
                        <a class="btn  @if(Request::segment(1) == 'statistic') btn-primary @endif" href="{{ route('statistic.index') }}">
                            <i data-feather="trending-up"></i> Statistika
                        </a>
                    </li>
                @else
                    <li class="nav-item">
                        <a class="btn" href="javascript:void(0);"
                           data-toggle="tooltip" data-placement="top"
                           data-original-title="Kirishga ruxsat yo'q">
                            <i data-feather="trending-up"></i> Statistika
                        </a>
                    </li>
                @endif


                @if(\Helper::checkUserActions(207))
                    <li class="nav-item">
                        <a class="btn  @if(Request::segment(1) == 'order') btn-primary @endif" href="{{ route('order.index') }}">
                            <i data-feather="check-square"></i> Buyurtmalar
                        </a>
                    </li>
                @else
                    <li class="nav-item">
                        <a class="btn" href="javascript:void(0);"
                           data-toggle="tooltip" data-placement="top"
                           data-original-title="Kirishga ruxsat yo'q">
                            <i data-feather="check-square"></i> Buyurtmalar
                        </a>
                    </li>
                @endif

                <li class="nav-item">
                    <a class="btn @if(Request::segment(1) == 'product') btn-primary @endif" href="{{ route('product.index') }}">
                        <i data-feather="package"></i> Maxsulotlar
                    </a>
                </li>

                <li class="nav-item">
                    <a class="btn @if(Request::segment(1) == 'order-history') btn-primary @endif" href="{{ route('order-history.index') }}">
                        <i class="fas fa-history"></i> Buyurtmalar tarixi
                    </a>
                </li>

                <li class="dropdown nav-item" data-menu="dropdown">
                    <a class="dropdown-toggle btn d-flex align-items-center" href="#" data-toggle="dropdown">
                        <span data-i18n="Dashboards">Do'kon</span>
                    </a>
                    <ul class="dropdown-menu">
                        @if(\Helper::checkUserActions(207))
                            <li class="active">
                                <a class="dropdown-item d-flex align-items-center" href="{{ route('partner.index') }}">
                                    <i class="fas fa-store-alt mr-1"></i> Do'konlar
                                </a>
                            </li>
                        @else
                            <li class="active">
                                <a class="dropdown-item d-flex align-items-center"
                                    href="javascript:void(0);"
                                    data-toggle="tooltip" data-placement="top"
                                    data-original-title="Kirishga ruxsat yo'q">
                                    <i class="fas fa-store-alt mr-1"></i> Do'konlar
                                </a>
                            </li>
                        @endif
                        <li>
                            <a class="dropdown-item d-flex align-items-center" href="{{ route('sub-category.index') }}">
                                <i data-feather="server" class="mr-1"></i> Kategoriyalar
                            </a>
                        </li>
                    </ul>
                </li>

                <li class="nav-item">
                    <a class="btn btn-primary" href="{{ route('firebase.index') }}">Firebase</a>
                </li>
            </ul>

        </div>

        <ul class="nav navbar-nav align-items-center ml-auto">

            <li class="nav-item d-none d-lg-block">
                <a class="nav-link nav-link-style">
                    <i class="ficon" data-feather="sun"></i>
                </a>
            </li>

            <li class="nav-item dropdown dropdown-notification mr-25">
                <a class="nav-link" href="javascript:void(0);" data-toggle="dropdown">
                    <i class="ficon" data-feather="bell"></i>
                    <span class="badge badge-pill badge-danger badge-up">2</span>
                </a>
            </li>

            <li class="nav-item dropdown dropdown-user">
                <a class="nav-link dropdown-toggle dropdown-user-link"
                   id="dropdown-user" href="javascript:void(0);" data-toggle="dropdown"
                   aria-haspopup="true" aria-expanded="false">
                    <div class="user-nav d-sm-flex d-none">
                        <span class="user-name font-weight-bolder">{{ \Auth::user()->name }}</span>
                    </div>
                    <span class="avatar">
                        <i class="fas fa-user"></i>
                        <span class="avatar-status-online"></span>
                    </span>
                </a>
                <div class="dropdown-menu dropdown-menu-right" aria-labelledby="dropdown-user">
                    @if(\Helper::checkUserActions(506))
                        <a class="dropdown-item @if(Request::segment(1) == 'user') active @endif" href="{{ route('user.index') }}">
                            <i class="mr-50" data-feather="user"></i> Foydalanuvchi
                        </a>
                    @else
                        <a class="dropdown-item" href="javascript:void(0);"
                            data-toggle="tooltip" data-placement="top"
                            data-original-title="Kirishga ruxsat yo'q">
                            <i class="mr-50" data-feather="user"></i> Foydalanuvchi
                        </a>
                    @endif

                    <a class="dropdown-item" href="{{ route('user.user_profile_show') }}">
                        <i class="mr-50" data-feather="settings"></i> Sozlash
                    </a>

                    <a class="dropdown-item" href="{{ route('logout') }}"
                       onclick="event.preventDefault(); document.getElementById('logout-form').submit();">
                        <i class="mr-50" data-feather="power"></i> {{ __('Logout') }}
                    </a>

                    <form id="logout-form" action="{{ route('logout') }}" method="POST" class="d-none">
                        @csrf
                    </form>
                </div>
            </li>

        </ul>
    </div>
</nav>
<!-- END: Header-->

    <!-- BEGIN: Content-->
    <div class="app-content content" style="padding-top: 80px; padding-left: 15px; padding-right: 15px;">

        @yield('content')

    </div>

    <!-- BEGIN: Content-->

<!-- BEGIN: Footer-->
<footer class="footer footer-static footer-light footer-shadow pt-0 pb-0">
    <p class="clearfix mb-0">
        <span class="float-md-left d-block d-md-inline-block mt-25">BarakaTop &copy; 2022
            <a class="ml-25" href="javascript:void(0);">barakaTop</a>
        </span>
    </p>
</footer>
<!-- END: Footer-->

@include('layouts.deleteModal')


<script src="{{ asset('js/jquery-3.6.js') }}"></script>
<!-- BEGIN: Vendor JS-->
<script src="{{ asset('vendors/js/vendors.min.js') }}"></script>
<!-- BEGIN Vendor JS-->

<script src="{{ asset('vendors/js/charts/chart.min.js') }}"></script>

<!-- BEGIN: Page Vendor JS-->
<script src="{{ asset('vendors/js/forms/select/select2.full.min.js') }}"></script>
<script src="{{ asset('vendors/js/forms/validation/jquery.validate.min.js') }}"></script>
<script src="{{ asset('vendors/js/pickers/flatpickr/flatpickr.min.js') }}"></script>
<!-- END: Page Vendor JS-->


<script src="{{ asset('vendors/js/ui/jquery.sticky.js') }}"></script>
<script src="{{ asset('vendors/js/extensions/dropzone.min.js') }}"></script>

<!-- BEGIN: Page Vendor JS-->
<script src="{{ asset('vendors/js/pickers/pickadate/picker.js') }}"></script>
<script src="{{ asset('vendors/js/pickers/pickadate/picker.date.js') }}"></script>
<script src="{{ asset('vendors/js/pickers/pickadate/picker.time.js') }}"></script>
<script src="{{ asset('vendors/js/pickers/pickadate/legacy.js') }}"></script>
<script src="{{ asset('vendors/js/pickers/flatpickr/flatpickr.min.js') }}"></script>
<!-- END: Page Vendor JS-->

<!-- BEGIN: Page Vendor JS-->
<script src="{{ asset('vendors/js/forms/cleave/cleave.min.js') }}"></script>
<script src="{{ asset('vendors/js/forms/cleave/addons/cleave-phone.us.js') }}"></script>
<!-- END: Page Vendor JS-->

<!-- BEGIN: Page Vendor JS-->
<script src="{{ asset('vendors/js/extensions/sweetalert2.all.min.js') }}"></script>
<script src="{{ asset('vendors/js/extensions/polyfill.min.js') }}"></script>
<!-- END: Page Vendor JS-->


<!-- BEGIN: Theme JS-->
<script src="{{ asset('js/core/app-menu.min.js') }}"></script>
<script src="{{ asset('js/core/app.min.js') }}"></script>
<script src="{{ asset('js/scripts/customizer.min.js') }}"></script>


<!-- BEGIN: Page Vendor JS-->
<script src="{{ asset('vendors/js/charts/apexcharts.min.js') }}"></script>
<!-- END: Page Vendor JS-->

<!-- END: Theme JS-->
<script src="{{ asset('js/scripts/extensions/ext-component-sweet-alerts.js') }}"></script>


<script src="{{ asset('js/scripts/forms/form-validation.js') }}"></script>
<script src="{{ asset('js/scripts/forms/pickers/form-pickers.js') }}"></script>


<script src="{{ asset('js/fancybox.3.7.min.js') }}"></script>

<!-- BEGIN: Page Vendor JS-->
<script src="{{ asset('vendors/js/tables/datatable/jquery.dataTables.min.js') }}"></script>
<script src="{{ asset('vendors/js/tables/datatable/datatables.bootstrap4.min.js') }}"></script>
<script src="{{ asset('vendors/js/tables/datatable/dataTables.responsive.min.js') }}"></script>
<script src="{{ asset('vendors/js/tables/datatable/responsive.bootstrap4.js') }}"></script>
<script src="{{ asset('vendors/js/tables/datatable/datatables.buttons.min.js') }}"></script>
<script src="{{ asset('vendors/js/tables/datatable/buttons.bootstrap4.min.js') }}"></script>
<script src="{{ asset('vendors/js/forms/validation/jquery.validate.min.js') }}"></script>
<!-- END: Page Vendor JS-->
<!-- BEGIN: Page JS-->


<script src="{{ asset('js/moment.min.js') }}"></script>
<script src="{{ asset('js/scripts/forms/form-validation.js') }}"></script>
<!-- END: Page JS-->
<!-- BEGIN: Page JS-->
<script src="{{ asset('js/scripts/components/components-modals.js') }}"></script>
<!-- END: Page JS-->
<script src="{{ asset('file_uploaded/image-uploader.js') }}"></script>

<script src="{{ asset('js/scripts/forms/form-input-mask.js?'.time()) }}"></script>

<script src="{{ asset('js/function_validate.js') }}"></script>
<script src="{{ asset('js/functionDelete.js') }}"></script>
<script src="{{ asset('js/functions.js') }}"></script>

@yield('script')

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
