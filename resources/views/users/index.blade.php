@extends('layouts.app')

@section('content')

        <div class="content-wrapper">
            <div class="content-body">
                <div class="form-modal-ex position-relative">
                    <!-- Button trigger modal -->
                    <a href="javascript:void(0);" data-url="{{ route('user.store') }}"
                       class="btn btn-outline-primary add-user-btn js_add_btn">Qo'shish</a>
                    <h3 class="text-center text-info position-absolute zindex-1" style="left: 45%; top: 12px;">Foydalanuvchilar</h3>
                    <!-- Modal -->
                </div>

                <!-- users list start -->
                <section class="app-user-list">
                    <!-- list section start -->
                    <div class="card">
                        <div class="card-datatable table-responsive pt-0">
                            <table class="table table-striped" id="user_datatable">
                                <thead class="thead-light">
                                    <tr>
                                        <th>№</th>
                                        <th>Ism familiya</th>
                                        <th>Telefon raqam</th>
                                        <th>Status</th>
                                        <th>Login</th>
                                        <th>vaqt</th>
                                        <th class="text-right">Actions</th>
                                    </tr>
                                </thead>
                                <tbody>

                                @foreach($users as $u)

                                    <tr class="js_this_tr" data-id="{{ $u->id }}">
                                        <td>{{ 1 + $loop->index }}</td>
                                        <td>{{ $u->name }}</td>
                                        <td>{{ \Helper::phoneFormat($u->phone) }}</td>
                                        <td>@if($u->status) faol @else nofaol @endif</td>
                                        <td>{{ $u->username }}</td>
                                        <td>{{ date('d.m.Y H:i', strtotime($u->created_at)) }}</td>
                                        <td class="text-right">
                                            <div class="d-flex justify-content-around">
                                                <a href="javascript:void(0);" class="text-primary js_edit_btn"
                                                   data-one_user_url="{{ route('user.oneUser', [$u->id]) }}"
                                                   data-update_url="{{ route('user.update', [$u->id]) }}"
                                                   title="Tahrirlash">
                                                    <i class="fas fa-pen mr-50"></i>
                                                </a>
                                                <a class="text-danger js_delete_btn" href="javascript:void(0);"
                                                   data-toggle="modal"
                                                   data-target="#deleteModal"
                                                   data-name="{{ $u->name }}"
                                                   data-url="{{ route('user.destroy', [$u->id]) }}" title="O\'chirish">
                                                    <i class="far fa-trash-alt mr-50"></i>
                                                </a>
                                            </div>
                                        </td>
                                    </tr>

                                @endforeach

                                </tbody>
                            </table>
                        </div>

                    </div>
                    <!-- list section end -->
                </section>
                <!-- users list ends -->

            </div>
        </div>

        @include('users.add_edit_user_modal')

@endsection


@section('script')

    <script>

        function huquqlari_borlarini_belgilash(user_priv) {
            let action_input = $('.js_huquqlar_ul .js_action')
            $.each(action_input, function(i, item) {
                let action = $(item)
                for(let j = 0; j < user_priv.length; j++) {
                    if(action.val() == user_priv[j].action_id)
                        action.prop('checked', true)
                }

            });
        }

        function user_form_clear(form) {
            form.find("input[type='text']").val('')
            form.remove('input[name="_method"]');

            let action_input = $('.js_huquqlar_ul .js_action')
            $.each(action_input, function(i, item) {
                $(item).prop('checked', false)
            });

        }

        $(document).ready(function() {
            var modal = $('#user_add_edit_modal')

            $('#user_datatable').DataTable({
                paging: true,
                pageLength: 20,
                lengthChange: false,
                searching: true,
                ordering: true,
                info: true,
                autoWidth: true,
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

            $(document).on('click', '.js_add_btn', function() {
                let url = $(this).data('url')
                let form = modal.find('.js_user_add_from')

                form.attr('action', url)
                user_form_clear(form)
                modal.modal('show')
            })


            $(document).on('click', '.js_edit_btn', function() {

                let one_url = $(this).data('one_user_url')
                let update_url = $(this).data('update_url')
                let form = modal.find('.js_user_add_from')
                user_form_clear(form)

                form.attr('action', update_url)
                form.append('<input type="hidden" name="_method" value="PUT">')
                $.ajax({
                    type: 'GET',
                    url: one_url,
                    dataType: 'JSON',
                    success: (response) => {
                        console.log(response)
                        if(response.status) {
                            form.find('.js_name').val(response.user.name)
                            form.find('.js_phone').val(response.user.phone)
                            form.find('.js_username').val(response.user.username)
                            form.find('.js_old_username').val(response.user.username)
                            let status = form.find('.js_status option')

                            $.each(status, function(i, item) {
                                if ($(item).val() == response.user.status) {
                                    $(item).attr('selected', true)
                                }
                            })

                            huquqlari_borlarini_belgilash(response.user.user_priv)
                        }
                        modal.modal('show')
                    },
                    error: (response) => {
                        console.log('error: ', response)
                    }
                })
            })



            $(document).on('click', '.js_action, .custom-control-label', function () {
                let action_invalid = $('.js_action_invalid')
                if(!action_invalid.hasClass('d-none')) {
                    action_invalid.addClass('d-none')
                }
            })

            /** User add **/
            $('.js_user_add_from').on('submit', function(e) {
               e.preventDefault()
                let form = $(this)
                let action = form.attr('action')

                let phone = form.find('.js_phone')
                let username = form.find('.js_username')
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
                            location.reload()
                        }
                        console.log(response)
                        if(typeof response.errors !== 'undefined') {
                            if (response.errors.name)
                                form.find('.js_name').addClass('is-invalid')

                            if (response.errors.phone)
                                phone.addClass('is-invalid')

                            if (response.errors.username) {
                                username.addClass('is-invalid')
                                username.siblings('.invalid-feedback').html('Loginni kiriting!')
                            }
                            if (response.errors.username == 'The username has already been taken.') {
                                username.addClass('is-invalid')
                                username.siblings('.invalid-feedback').html('Bunday login mavjud')
                            }

                            if(response.errors.password) {
                                password.addClass('is-invalid')
                                password.siblings('.invalid-feedback').html('Parolni kiriting')
                            }
                            if(response.errors.password == 'The password must be at least 6 characters.') {
                                password.addClass('is-invalid')
                                password.siblings('.invalid-feedback').html('Parol kamida 6 ta belgidan iborat bo\'lishi kerak')
                            }

                            if(response.errors.action == 'The action field is required.') {
                                form.find('.js_action_invalid').removeClass('d-none')
                            }
                        }
                    },
                    error: (response) => {
                        console.log('error: ',response)
                    }
                })
            });
        });
    </script>
@endsection
