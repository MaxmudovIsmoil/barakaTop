@extends('layouts.app')

@section('style')
    <link rel="stylesheet" type="text/css" href="{{ asset('vendors/css/charts/apexcharts.css') }}">
    <link rel="stylesheet" type="text/css" href="{{ asset('vendors/css/extensions/toastr.min.css') }}">
    <!-- BEGIN: Page CSS-->

    <link rel="stylesheet" type="text/css" href="{{ asset('css/core/menu/menu-types/vertical-menu.min.css') }}">
    <link rel="stylesheet" type="text/css" href="{{ asset('css/pages/dashboard-ecommerce.min.css') }}">
    <link rel="stylesheet" type="text/css" href="{{ asset('css/plugins/charts/chart-apex.min.css') }}">
    <link rel="stylesheet" type="text/css" href="{{ asset('css/plugins/extensions/ext-component-toastr.min.css') }}">
    <!-- END: Page CSS-->
@endsection

@section('content')

    <div class="content-wrapper">
            <div class="content-header">
                <form action="{{ route('statistic.getStatistic') }}" method="POST" name="my-form" id="js_statistic_form">
                    <div class="row">
                        @csrf
                        <div class="col-md-2 form-group">
                            <input type="date" name="start_date"
                                   class="form-control flatpickr-input flatpickr-date-normal js_start_date"
                                   placeholder="{{ date('d.m.Y') }}">
                            <div class="invalid-feedback">Sanani tanlang!</div>
                        </div>
                        <div class="col-md-2 form-group">
                            <input type="date" name="end_date"
                                   class="form-control flatpickr-input flatpickr-date-normal js_end_date"
                                   placeholder="{{ date('d.m.Y') }}">
                            <div class="invalid-feedback">Sanani tanlang!</div>
                        </div>
                        <div class="col-md-3 form-group">
                            <button type="button" class="btn btn-outline-primary js_btn_show"><i class="fas fa-eye"></i> Ko'rish</button>
                        </div>
                    </div>
                </form>

            </div>
            <div class="content-body">

                <section id="dashboard-ecommerce">
                    <div class="row">
                        <div class="col-md-4 pl-0">
                            <div class="col-lg-12 col-12 pr-0">
                                <div class="card card-statistics">
                                    <div class="card-header pb-0 pl-2">
                                        <h4 class="card-title">Buyurtmalar</h4>
                                    </div>
                                    <div class="card-body statistics-body">
                                        <div class="row">
                                            <div class="col-md-4 col-sm-6 col-12 pl-0 mb-0">
                                                <div class="media">
                                                    <div class="avatar bg-light-danger mr-1">
                                                        <div class="avatar-content">
                                                            <i data-feather="shopping-cart" class="font-medium-5"></i>
                                                        </div>
                                                    </div>
                                                    <div class="media-body my-auto">
                                                        <h4 class="font-weight-bolder mb-0">
                                                            @isset($order_all)
                                                                {{ $order_all }}
                                                            @endisset
                                                        </h4>
                                                        <p class="card-text font-small-3 mb-0">Jami</p>
                                                    </div>
                                                </div>
                                            </div>
                                            <div class="col-md-4 col-sm-6 col-12 pl-0 mb-0">
                                                <div class="media">
                                                    <div class="avatar bg-light-primary mr-1">
                                                        <div class="avatar-content">
                                                            <i data-feather="activity" class="font-medium-5"></i>
                                                        </div>
                                                    </div>
                                                    <div class="media-body my-auto">
                                                        <h4 class="font-weight-bolder mb-0 js_order_tushgan_h4">
                                                            @isset($order_tushgan)
                                                                {{ $order_tushgan }}
                                                            @endisset
                                                        </h4>
                                                        <p class="card-text font-small-3 mb-0">Tushgan</p>
                                                    </div>
                                                </div>
                                            </div>
                                            <div class="col-md-4 col-sm-6 col-12 pl-0 mb-0">
                                                <div class="media">
                                                    <div class="avatar bg-light-info mr-1">
                                                        <div class="avatar-content">
                                                            <i data-feather="trending-up" class="font-medium-5"></i>
                                                        </div>
                                                    </div>
                                                    <div class="media-body my-auto">
                                                        <h4 class="font-weight-bolder mb-0 js_order_bajarilgan_h4">
                                                            @isset($order_bajarilgan)
                                                                {{ $order_bajarilgan }}
                                                            @endisset
                                                        </h4>
                                                        <p class="card-text font-small-3 mb-0">Bajarilgan</p>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>


                            <div class="col-lg-12 col-12 pr-0">
                                <div class="card card-statistics">
                                    <div class="card-header pb-0 pl-2">
                                        <h4 class="card-title">Mijozlar</h4>
                                    </div>
                                    <div class="card-body statistics-body">
                                        <div class="row">
                                            <div class="col-md-4 col-sm-6 col-12 pl-0 mb-0">
                                                <div class="media">
                                                    <div class="avatar bg-light-primary mr-1">
                                                        <div class="avatar-content">
                                                            <i data-feather="users" class="font-medium-5"></i>
                                                        </div>
                                                    </div>
                                                    <div class="media-body my-auto">
                                                        <h4 class="font-weight-bolder mb-0">
                                                            @isset($client_all)
                                                                {{ $client_all }}
                                                            @endisset
                                                        </h4>
                                                        <p class="card-text font-small-3 mb-0">Jami</p>
                                                    </div>
                                                </div>
                                            </div>
                                            <div class="col-md-4 col-sm-6 col-12 pl-0 mb-0">
                                                <div class="media">
                                                    <div class="avatar bg-light-info mr-1">
                                                        <div class="avatar-content">
                                                            <i data-feather="user-check" class="font-medium-5"></i>
                                                        </div>
                                                    </div>
                                                    <div class="media-body my-auto">
                                                        <h4 class="font-weight-bolder mb-0 js_faol_client_h4">
                                                            @isset($client_active_count)
                                                                {{ $client_active_count }}
                                                            @endisset
                                                        </h4>
                                                        <p class="card-text font-small-3 mb-0">Faol</p>
                                                    </div>
                                                </div>
                                            </div>
                                            <div class="col-md-4 col-sm-6 col-12 pl-0 mb-0">
                                                <div class="media">
                                                    <div class="avatar bg-light-success mr-1">
                                                        <div class="avatar-content">
                                                            <i data-feather="user" class="font-medium-5"></i>
                                                        </div>
                                                    </div>
                                                    <div class="media-body my-auto">
                                                        <h4 class="font-weight-bolder mb-0 js_yangi_client_h4">
                                                            @isset($client_new)
                                                                {{ $client_new }}
                                                            @endisset
                                                        </h4>
                                                        <p class="card-text font-small-3 mb-0">Yangilar</p>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>


                            <div class="col-lg-12 col-12 pr-0">
                                <div class="card">
                                    <div class="card-header">
                                        <div>
                                            <h2 class="font-weight-bolder mb-0 js_summa_h2">
                                                @isset($summa)
                                                    {{ $summa }}
                                                @endisset
                                            </h2>
                                            <p class="card-text">Jami summa</p>
                                        </div>
                                        <div class="avatar bg-light-success p-50 m-0">
                                            <div class="avatar-content">
                                                <i data-feather="dollar-sign" class="ont-medium-5"></i>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <div class="col-8">
                            <div class="card">
                                <div class="card-body" style="padding: 5px 5px 10px 0;">
                                    <canvas class="line-chart-ex chartjs js_diagram_chart_convas" data-height="450"></canvas>
                                </div>
                            </div>
                        </div>
                    </div>

                </section>

            </div>
        </div>

@endsection


@section('script')

{{--    <script src="{{ asset('js/scripts/charts/chart-chartjs.js') }}"></script>--}}

    <script>

        function create_diagram_chart(
            lineChartEx, tooltipShadow, grid_line_color, labelColor,
            Ox_oqi, lineChartDanger, lineChartPrimary, warningColorShade,
            order_data, client_data)
        {
            return new Chart(lineChartEx, {
                type: 'line',
                plugins: [{
                    beforeInit: function (chart) {
                        chart.legend.afterFit = function () {
                            this.height += 10;
                        };
                    }
                }],
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    backgroundColor: false,
                    hover: {
                        mode: 'label'
                    },
                    tooltips: {
                        // Updated default tooltip UI
                        shadowOffsetX: 1,
                        shadowOffsetY: 1,
                        shadowBlur: 8,
                        shadowColor: tooltipShadow,
                        backgroundColor: window.colors.solid.white,
                        titleFontColor: window.colors.solid.black,
                        bodyFontColor: window.colors.solid.black
                    },
                    layout: {
                        padding: {
                            top: -15,
                            bottom: -25,
                            left: -15
                        }
                    },
                    scales: {
                        xAxes: [
                            {
                                display: true,
                                scaleLabel: {
                                    display: true
                                },
                                gridLines: {
                                    display: true,
                                    color: grid_line_color,
                                    zeroLineColor: grid_line_color
                                },
                                ticks: {
                                    fontColor: labelColor
                                }
                            }
                        ],
                        yAxes: [
                            {
                                display: true,
                                scaleLabel: {
                                    display: true
                                },
                                ticks: {
                                    stepSize: 5,
                                    min: 0,
                                    max: 30,
                                    fontColor: labelColor
                                },
                                gridLines: {
                                    display: true,
                                    color: grid_line_color,
                                    zeroLineColor: grid_line_color
                                }
                            }
                        ]
                    },
                    legend: {
                        position: 'top',
                        align: 'start',
                        labels: {
                            usePointStyle: true,
                            padding: 25,
                            boxWidth: 9
                        }
                    }
                },
                data: {
                    labels: Ox_oqi,
                    datasets: [
                        {
                            data: order_data,
                            label: 'Buyurtmalar',
                            borderColor: lineChartDanger,
                            lineTension: 0.5,
                            pointStyle: 'circle',
                            backgroundColor: lineChartDanger,
                            fill: false,
                            pointRadius: 1,
                            pointHoverRadius: 5,
                            pointHoverBorderWidth: 5,
                            pointBorderColor: 'transparent',
                            pointHoverBorderColor: window.colors.solid.white,
                            pointHoverBackgroundColor: lineChartDanger,
                            pointShadowOffsetX: 1,
                            pointShadowOffsetY: 1,
                            pointShadowBlur: 5,
                            pointShadowColor: tooltipShadow
                        },
                        {
                            data: client_data,
                            label: 'Mijozlar',
                            borderColor: lineChartPrimary,
                            lineTension: 0.5,
                            pointStyle: 'circle',
                            backgroundColor: lineChartPrimary,
                            fill: false,
                            pointRadius: 1,
                            pointHoverRadius: 5,
                            pointHoverBorderWidth: 5,
                            pointBorderColor: 'transparent',
                            pointHoverBorderColor: window.colors.solid.white,
                            pointHoverBackgroundColor: lineChartPrimary,
                            pointShadowOffsetX: 1,
                            pointShadowOffsetY: 1,
                            pointShadowBlur: 5,
                            pointShadowColor: tooltipShadow
                        },
                    ]
                }
            });
        }

        function get_data_diagram(url, order_data, client_data) {
            $.ajax({
                url: url,
                type: 'GET',
                dataType: 'JSON',
                success: (response) => {

                    order_data = response.order_data;
                    client_data = response.client_data;

                },
                error: (response) => {
                    console.log('error: ', response)
                }
            })
        }
        $(window).on('load', function () {
            var chartWrapper = $('.chartjs'),
                lineChartEx = $('.line-chart-ex');

            var Ox_oqi = ['01:00', '02:00', '03:00','04:00', '05:00', '06:00','07:00', '08:00',
                '09:00', '10:00', '11:00', '12:00', '13:00', '14:00', '15:00', '16:00', '17:00',
                '18:00', '19:00', '20:00', '21:00', '22:00', '23:00', '24:00'];

            let url = '{{ route('statistic.get_order_and_client_data_for_diagram') }}'

            // var order_data  = [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            // var client_data = [0, 0, 0, 0, 0, 0, 0, 2, 3, 1, 0, 0, 0, 3, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0];
            var order_data, client_data;

            get_data_diagram(url, order_data, client_data)


            // Color Variables
            var warningColorShade = '#ffe802',
                tooltipShadow = 'rgba(0, 0, 0, 0.25)',
                lineChartPrimary = '#666ee8',
                lineChartDanger = '#ff4961',
                labelColor = '#6e6b7b',
                grid_line_color = 'rgba(200, 200, 200, 0.2)'; // RGBA color helps in dark layout



            chartWrapper.each(function () {
                $(this).wrap($('<div style="height:' + this.getAttribute('data-height') + 'px"></div>'));
            });


            // --------------------------------------------------------------------

            var diagramChart = create_diagram_chart(lineChartEx, tooltipShadow, grid_line_color, labelColor,
                Ox_oqi, lineChartDanger, lineChartPrimary, warningColorShade,
                order_data, client_data)

            // --------------------------------------------------------------------

            $(document).on('click', '.js_btn_show', function(e) {
                e.preventDefault();
                let form = $(this).closest('#js_statistic_form')

                $.ajax({
                    type: 'POST',
                    url: form.attr('action'),
                    data: form.serialize(),
                    dataType: 'JSON',
                    success: (response) => {

                        if(!response.status) {
                            if(typeof response.errors !== 'undefined') {
                                if (response.errors.start_date)
                                    form.find('.js_start_date').addClass('is-invalid')
                                if (response.errors.end_date)
                                    form.find('.js_end_date').addClass('is-invalid')
                            }
                        }

                        if(response.status) {
                            $('.js_order_tushgan_h4').html(response.result.order_tushgan)
                            $('.js_order_bajarilgan_h4').html(response.result.order_bajarilgan)
                            $('.js_faol_client_h4').html(response.result.client_active_count)
                            $('.js_yangi_client_h4').html(response.result.client_new)
                            $('.js_summa_h2').html(response.result.summa)


                            Ox_oqi = response.result.days;
                            order_data  = response.result.order_data;
                            client_data = response.result.client_data;

                            create_diagram_chart(lineChartEx, tooltipShadow, grid_line_color, labelColor,
                                Ox_oqi, lineChartDanger, lineChartPrimary, warningColorShade,
                                order_data, client_data)
                        }

                        console.log('res:', response)
                    },
                    error: (response) => {
                        console.log('error: ', response)
                    }
                })

            })
        });
    </script>

@endsection
