@extends('layouts.app')

@section('content')

    <div class="content-wrapper">

        <div class="content-body position-relative">
            <!-- add btn click show modal -->
            <div class=""  style="z-index: 1">

                <form action="{{ route('order-history.getOrderHistory') }}" name="my-form" id="js_order_history_form">
                    <div class="row">
                        <div class="col-md-2 form-group">
                            <input type="date" name="date_start" class="form-control flatpickr-input flatpickr-date-normal js_date_start" placeholder="dan">
                        </div>
                        <div class="col-md-2 form-group">
                            <input type="date" name="date_end" class="form-control flatpickr-input flatpickr-date-normal js_date_end" placeholder="gacha">
                        </div>
                        <div class="col-md-3 form-group">
                            <select name="order_status" class="form-control js_order_status">
                                <option value="4" @isset($status) @if($status == 4) selected @endif @endisset>Bajarilgan buyurtmalar</option>
                                <option value="3" @isset($status) @if($status == 3) selected @endif @endisset>Bekor qilingan buyurtmalar</option>
                            </select>
                        </div>
                    </div>
                </form>
            </div>

            <!-- users list start -->
            <section class="app-user-list position-relative">
                <!-- list section start -->

                <div class="card">
                    <div class="card-datatable table-responsive pt-0">
                        <table class="table table-striped" id="datatable">
                            <thead class="thead-light">
                                <tr>
                                    <th>№</th>
                                    <th>Partner</th>
                                    <th>Mijoz Ismi</th>
                                    <th>Telefon raqam</th>
                                    <th>Manzil</th>
                                    <th>Summa</th>
                                    <th>Izoh</th>
                                    <th>Buyurtma vaqti</th>
                                    <th>Kim qo'shgan</th>
                                    <th class="text-right">Harakatlar</th>
                                </tr>
                            </thead>
                            <tbody>
                                @isset($order_history)
                                    @php $summa = 0; @endphp
                                    @foreach($order_history as $o)
                                        @php
                                            foreach($o->order_details as $od) {
                                                $summa += $od->price * $od->quantity;
                                            }
                                        @endphp
                                        <tr>
                                            <td>{{ 1 + $loop->index }}</td>
                                            <td>
                                                <a href="javascript:void(0);"
                                                   class="badge badge-pill badge-light-info"
                                                   data-toggle="modal" data-target=".partner_modal_{{ $o->id }}"
                                                   style="font-size: 14px;">{{ optional($o->partner)->name }}</a>

                                                <div class="modal fade modal-primary text-left partner_modal_{{ $o->id }}" tabindex="-1" role="dialog" aria-hidden="true">
                                                    <div class="modal-dialog modal-dialog-centered" role="document">
                                                        <div class="modal-content">
                                                            <div class="modal-header">
                                                                <h5 class="modal-title">{{ optional($o->partner)->name }}</h5>
                                                                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                                                                    <span aria-hidden="true">&times;</span>
                                                                </button>
                                                            </div>
                                                            <div class="modal-body">
                                                                <p>Telefon: <span class="text-info">{{ Helper::phoneFormat(optional($o->partner)->phone) }}</span></p>
                                                                <p>Ish vaqti:
                                                                    <span class="text-info">{{ date('H : i', strtotime(optional($o->partner)->open_time)) }}</span>&sbquo;
                                                                    <span class="text-info">{{ date('H : i', strtotime(optional($o->partner)->close_time)) }}</span> </p>
                                                            </div>
                                                        </div>
                                                    </div>
                                                </div>
                                            </td>
                                            <td>{{ optional($o->client)->name }}</td>
                                            <td>{{ Helper::phoneFormat($o->phone) }}</td>
                                            <td>
                                                <span style="font-weight: bold;">
                                                    <i class="fas fa-map-marker-alt map"></i> {{ $o->to }}
                                                </span>
                                            </td>
                                            <td><span>{{ number_format($summa,0,". "," ") }}</span></td>
                                            <td>{{ $o->comments }}</td>
                                            <td>{{ date('d.m.Y  H:i', strtotime($o->date_created)) }}</td>
                                            <td>{{ optional($o->user)->name }}</td>
                                            <td>
                                                <div class="d-flex justify-content-around">

                                                    <a href="javascript:void(0);" class="text-info"
                                                       data-toggle="modal" data-target="#order_details_modal_{{ $o->id }}"
                                                       title="Malumot"><i class="fas fa-eye"></i>
                                                    </a>

                                                    <div class="modal fade modal-danger text-left" id="order_details_modal_{{ $o->id }}" tabindex="-1" data-backdrop="static">
                                                        <div class="modal-dialog modal-lg modal-dialog-centered" role="document">
                                                            <div class="modal-content">
                                                                <div class="modal-header">
                                                                    <h5 class="modal-title">{{ optional($o->client)->name." ".\Helper::phoneFormat($o->phone) }}</h5>
                                                                    <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                                                                        <span aria-hidden="true">&times;</span>
                                                                    </button>
                                                                </div>
                                                                <div class="modal-body p-0">
                                                                    <table class="table table-striped">
                                                                        <thead>
                                                                            <th>№</th>
                                                                            <th>Maxulot nomi</th>
                                                                            <th>Miqdori</th>
                                                                            <th>Narxi</th>
                                                                        </thead>
                                                                        <tbody>
                                                                        @php $i = 1; @endphp
                                                                        @foreach ($o->order_details as $od)
                                                                            <tr>
                                                                                <td>{{ $i++ }}</td>
                                                                                <td>{{ $od->product->name }}</td>
                                                                                <td>{{ $od->quantity }}</td>
                                                                                <td>{{ number_format($od->price, 0, ". ", " ") }}</td>
                                                                            </tr>
                                                                        @endforeach
                                                                            <tr class="text-right">
                                                                                <td colspan="4">
                                                                                    <p class="mr-5 mb-0">{{ number_format($summa,0,". "," ") }}</p>
                                                                                </td>
                                                                            </tr>
                                                                        </tbody>
                                                                    </table>
                                                                </div>
                                                                <div class="modal-footer">
                                                                    <button type="button" class="btn btn-secondary" data-dismiss="modal">Yopish</button>
                                                                </div>
                                                            </div>
                                                        </div>
                                                    </div>


                                                @if(\Helper::checkUserActions(510))
                                                        <a class="text-danger js_delete_btn" href="javascript:void(0);"
                                                           data-toggle="modal"
                                                           data-target="#deleteModal"
                                                           data-name="{{ $o->name }}" data-url="{{ route('order-history.destroy', [$o->id]) }}" title="O'chirish">
                                                            <i class="far fa-trash-alt mr-50"></i>
                                                        </a>
                                                    @else
                                                        <a class="text-secondary" href="javascript:void(0);"
                                                           data-toggle="tooltip" data-placement="top"
                                                           data-original-title="Ruxsat yo'q">
                                                            <i class="far fa-trash-alt mr-50"></i>
                                                        </a>
                                                    @endif
                                                </div>
                                            </td>
                                        </tr>
                                    @endforeach
                                @endisset
                            </tbody>
                        </table>
                    </div>
                </div>
                <!-- list section end -->
            </section>
            <!-- users list ends -->
        </div>
    </div>

@endsection


@section('script')

    <script>
        function clear_from(form) {
            form.find('.js_date_start').val('')
            form.find('.js_date_end').val('')
        }

        $(document).ready(function() {

            let datatable = $('#datatable').DataTable({
                paging: true,
                pageLength: 20,
                lengthChange: false,
                searching: true,
                ordering: true,
                info: true,
                autoWidth:  true,
                language: {
                    search: "",
                    searchPlaceholder: " Izlash...",
                    sLengthMenu: "Кўриш _MENU_ тадан",
                    sInfo: "Ko'rish _START_ dan _END_ gacha _TOTAL_ jami",
                    emptyTable: "Ma'lumot mavjud emas",
                    sInfoFiltered: "(Jami _MAX_ ta yozuvdan filtrlangan)",
                    sZeroRecords: "Hech qanday mos yozuvlar topilmadi",
                    oPaginate: {
                        sNext: "Keyingi",
                        sPrevious: "Oldingi",
                    },
                }
            });

            datatable_column_number_format(datatable, 5);


            function order_history_form() {
                let form = $("#js_order_history_form")
                let date_start  = form.find('.js_date_start').val()
                let date_end    = form.find('.js_date_end').val()
                if(date_start && date_end) {
                    form.submit()
                }
            }

            $(document).on('input', '.js_date_start', function() {
                order_history_form()
            });

            $(document).on('input', '.js_date_end', function() {
                order_history_form()
            });

            $(document).on('input', '.js_order_status', function() {
                order_history_form()
            });


            $( ".js_date_start" ).flatpickr({
                dateFormat: "d.m.Y",
                disableMobile: "true",
                defaultDate: '{{ isset($date_start) ? $date_start : "dan" }}'
            });

            $( ".js_date_end" ).flatpickr({
                dateFormat: "d.m.Y",
                disableMobile: "true",
                defaultDate: '{{ isset($date_end) ? $date_end : 'gacha' }}'
            });

        });
    </script>

@endsection
