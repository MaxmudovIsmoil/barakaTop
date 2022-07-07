@extends('layouts.app')


@section('content')
    @csrf
    <div class="content-wrapper">
        <div class="content-header" style="margin-bottom: 10px;">
            <div class="btn-group btn-block">
                <a href="{{ route("order.getOrders", [1]) }}" data-id="1" class="btn btn-primary js_btn_cat">Yangi buyurtmalar</a>
                <a href="{{ route("order.getOrders", [2]) }}" data-id="2" class="btn btn-outline-primary js_btn_cat">Bekor qilingan buyurtmalar</a>
                <a href="{{ route("order.getOrders", [3]) }}" data-id="3" class="btn btn-outline-primary js_btn_cat">Yopilgan buyurtmalar</a>
            </div>
        </div>

        <div class="content-body">
            <!-- add btn click show modal -->
            @if(\Helper::checkUserActions(201))
                <a href="#" data-store_url="{{ route('order.store') }}" class="btn btn-outline-primary add_btn js_add_btn">Qo'shish</a>
            @else
                <a href="javascript:void(0)" class="btn btn-outline-primary add_btn"
                   data-toggle="tooltip" data-placement="top"
                   data-original-title="Ruxsat yo'q">Qo'shish</a>
            @endif
            <!-- users list start -->
            <section class="app-user-list">
                <!-- list section start -->
                <div class="card">
                    <div class="card-datatable table-responsive pt-0">
                        <table class="table table-striped" id="datatable">
                            <thead class="thead-light">
                                <tr>
                                    <th>№</th>
                                    <th>Mijoz</th>
                                    <th>Pgone</th>
                                    <th>Nanzil (dan, ga)</th>
                                    <th>summa</th>
                                    <th>Status</th>
                                    <th>date_created</th>
                                    <th class="text-right">Harakatlar</th>
                                </tr>
                            </thead>
                            <tbody></tbody>
                        </table>
                    </div>
                </div>
                <!-- list section end -->
            </section>
            <!-- users list ends -->
        </div>
    </div>

    <!-- Edit Modal -->
    @include('order.add_edit_order_modal')

@endsection

<script src="https://www.gstatic.com/firebasejs/8.3.0/firebase-app.js"></script>
<script src="https://www.gstatic.com/firebasejs/8.3.0/firebase-messaging.js"></script>

<script src="{{ asset('js/function_orders.js') }}"></script>

@section('script')

    <script>

        $(document).ready(function() {
            var token = $('input[name="_token"]').val();

            var modal = $(document).find('#add_edit_modal');
            var form = modal.find('#js_add_edit_from');

            let url = '{{ route("order.getOrders", [1]) }}'
            var order_table = create_datatable(url)


            $(document).on('click', '.js_btn_cat', function(e) {
                e.preventDefault()

                $(this).siblings().removeClass('btn-primary')
                $(this).siblings().addClass('btn-outline-primary')

                $(this).removeClass('btn-outline-primary')
                $(this).addClass('btn-primary')

                let id = $(this).data('id');
                if(id === 2 || id === 3)
                    $('.js_add_btn').addClass('d-none')
                else
                    $('.js_add_btn').removeClass('d-none')

                let url =  $(this).attr('href');
                order_table = create_datatable(url)

            })


            /******************* order status btns ****************/
            /** Qabul qilish **/
            $(document).on('click', '.js_qabul_qilish_btn', function() {
                let url = $(this).data('status_update_url')
                let status = $(this).data('status');
                buyurtma_status_ozgartirish_btn_icons_uchun(url, status, order_table)
            })

            /** Tayyor bo'ldi **/
            $(document).on('click', '.js_tayyor_boldi_btn', function() {
                let url = $(this).data('status_update_url')
                let status = $(this).data('status')
                buyurtma_status_ozgartirish_btn_icons_uchun(url, status, order_table)
            })

            /** Buyurtmani yopish **/
            $(document).on('click', '.js_yopish_btn', function() {
                let url = $(this).data('status_update_url')
                let status = $(this).data('status')
                buyurtma_status_ozgartirish_btn_icons_uchun(url, status, order_table)
            })
            /******************* ./order status btns ****************/

            /** Qo'shish btn **/
            $(document).on('click', '.js_add_btn', function(e) {
                e.preventDefault()

                let action = $(this).data('store_url');
                modal.find('.modal-title').html("Buyurtma qo'shish");
                form.attr('action', action);
                form.data('type', 'store')
                form_clear(form)
                modal.find('.js_form_save_btn').removeClass('d-none')

                let partner_id = $('.js_partner_id option:selected').val();
                product_sub_category(partner_id)


                let parent_id = $(".js_sub_category option").last().val();

                create_card_product_at_modal(partner_id, parent_id)
                form.find('.js_savatcha').html('')
                savatchadagi_barcha_summa_va_soni()

                modal.modal('show');
            });

            $(document).on('change', '.js_partner_id', function() {
                let partner_id = $(this).val()
                product_sub_category(partner_id)
            })

            /** Tahrirlash btn **/
            $(document).on('click', '.js_edit_btn', function(e){
                e.preventDefault();
                form_clear(form)

                modal.find('.modal-title').html('Maxsulot tahrirlash')
                let url = $(this).data('one_data_url')
                let update_url = $(this).data('update_url')
                form.attr('action', update_url)

                form.data('type', 'update')

                let partner_id = form.find('.js_partner_id option:selected').val();
                product_sub_category(partner_id)

                $('.js_sub_category').val(0).trigger('change');

                let parent_id = form.find('.js_sub_category option:selected').val();
                console.log('p: ', parent_id)
                create_card_product_at_modal(partner_id, parent_id)

                form.find('.js_savatcha').html('')
                savatchadagi_barcha_summa_va_soni()


                $.ajax({
                    url: url,
                    type: "GET",
                    dataType: "json",
                    success: (response) => {

                        form.append("<input type='hidden' name='_method' value='PUT'>");
                        if(response.status) {
                            form.find('.js_phone').val(response.order.phone)
                            form.find('.js_phone').attr('old_phone', response.order.phone)
                            form.find('.js_to').val(response.order.to)

                            mijoz_bazada_bolsa_ismini_olish(response.order.phone)

                            savatchadagi_maxsulotlar_taxrirlash_uchun(response.order_details)
                        }
                        modal.modal('show')
                    },
                    error: (response) => {
                        console.log('error: ',response)
                    }
                });
            });



            /** Maxsulot buyurtma qilish uchun modalga tegishli hodisalalr **/
            $(document).on('change', '.js_sub_category', function () {
                let partner_id = $('.js_partner_id option:selected').val()
                let parent_id = $(this).val()
                let name = $('.js_name').val()

                create_card_product_search_product_name(partner_id, parent_id, name, token)
            })

            $(document).on('input', '.js_name', function () {
                let partner_id = $('.js_partner_id option:selected').val()
                let parent_id = $('.js_sub_category option:selected').val()
                let name = $(this).val()

                create_card_product_search_product_name(partner_id, parent_id, name, token)
            })


            $(document).on('click', '.js_card_product', function() {
                let product_id = $(this).data('product_id')
                let name = $(this).find('.card-product-name').siblings('p').html()
                let price = $(this).find('.card-product-price').data('price')

                savatchaga_yangi_maxsulot_qoshish(product_id, name, price)

                if(!$(this).hasClass('product-cash')) {
                    $(this).addClass('product-add')
                }

                savatchadagi_barcha_summa_va_soni()

                if(!$(".js_savatcha_error").hasClass('d-none')) {
                    $('.js_savatcha_error').addClass('d-none')
                }
            })

            $(document).on('click', '.js_kamaytirish_btn', function(e) {
                e.preventDefault()
                let product_cash = $(this).closest('.js_product_cash')
                savatchadagi_kamaytirish_btn(product_cash)
            })

            $(document).on('input', '.js_product_count', function () {
                let v = $(this).val()
                if(v > 0 && v <= 20)
                    savatchadagi_barcha_summa_va_soni()
            })

            $(document).on('click', '.js_oshirish_btn', function(e) {
                e.preventDefault()
                let product_cash = $(this).closest('.js_product_cash')
                savatchadagi_oshirish_btn(product_cash)
            })

            $(document).on('click', '.js_product_cash_remove_btn', function() {
                let product_id = $(this).closest('.js_product_cash').data('product_id')
                savatchadan_ochirish(product_id)
            })

            $(document).on('input', '.js_phone', function() {
                let phone = $(this).val()
                mijoz_bazada_bolsa_ismini_olish(phone)
            })

            $(document).on('click', '.client-name-edit-icon', function() {
                let client_name = $(this).siblings('.js_client_name')
                client_name.attr('readonly', false)
                client_name.focus()
            })

            $(document).on('focusout', '.js_client_name', function() {
                if($(this).val() != '') {
                    $(this).attr('readonly', true)
                    $(this).siblings('.client-name-edit-icon').removeClass('d-none')
                }
            })


            // buyurtmani saqalsh
            $(document).on('click', '.js_form_save_btn', function(e) {
                e.preventDefault()

                buyurtmani_saqlash()
            })

            // buyurtmani bekor qilish
            $(document).on('submit', '.js_order_close_form', function(e) {
                e.preventDefault()
                let form = $(this)
                let modal = form.closest('.modal-danger')
                let status = modal.find('.js_status').val()
                let comment = modal.find('.js_comment').val()
                let _token = form.find('input[name="_token"]').val()

                $.ajax({
                    url: form.attr('action'),
                    type: 'POST',
                    data: { '_token': _token, 'status': status, 'comment': comment },
                    dataType: 'JSON',
                    success: (response) => {
                        console.log(response)
                        if(response.status) {
                            modal.modal('hide')
                            order_table.draw()
                        }
                    },
                    error: (response) => {
                        console.log('error: ', response)
                    }
                })
            })

        });

    </script>

    <script>
        var firebaseConfig = {
            apiKey: "AIzaSyBf4ZqENl_Noe6v9LrH7jCrK1vjWFfkAFA",
            authDomain: "laravel-firebase-app-9d9ca.firebaseapp.com",
            projectId: "laravel-firebase-app-9d9ca",
            storageBucket: "laravel-firebase-app-9d9ca.appspot.com",
            messagingSenderId: "324803386436",
            appId: "1:324803386436:web:374888956c99863b1b7011",
            measurementId: "G-HYMMVELHT8"
        };

        firebase.initializeApp(firebaseConfig);
        const messaging = firebase.messaging();

        messaging.onMessage(function(payload) {

            console.log('order payload: ', payload)

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
