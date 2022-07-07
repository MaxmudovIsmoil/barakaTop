@extends('layouts.app')


@section('content')

    <div class="content-wrapper">
            <div class="content-body">
                <a href="{{ route('partner.index') }}" class="position-absolute btn_back zindex-1 p-0" title="Orqaga qaytish">
                    <i class="fas fa-long-arrow-alt-left"></i>
                </a>
                <h3 class="text-center text-info position-absolute zindex-1" style="left: 43%; top: 2.4%">Do'kon tahrirlash</h3>
                <div class="card pt-5">
                    <form action="{{ route('partner.update', [$partner->id]) }}" method="POST" class="js_partner_add_form" enctype="multipart/form-data">
                        @csrf
                        @method('PUT')
                        <div class="modal-body">
                            <div class="needs-validation">
                                <div class="row">
                                    <div class="col-md-3">
                                        <label>Kategoriyani tanlang</label>
                                        <select class="form-control js_group_id select2" name="group_id">
                                            @foreach($partner_group as $pg)
                                                <option @if($partner->group_id == $pg->id) selected @endif value="{{ $pg->id }}">{{ $pg->name }}</option>
                                            @endforeach
                                        </select>
                                    </div>
                                    <div class="col-md-3">
                                        <label>Hududni tanlang</label>
                                        <select class="form-control js_region_id select2" id="region_id" name="region_id">
                                            @foreach($region as $r)
                                                <option @if($partner->region_id == $r->id) selected @endif value="{{ $r->id }}">{{ $r->name }}</option>
                                            @endforeach
                                        </select>
                                    </div>
                                    <div class="col-md-6">
                                        <div class="form-group">
                                            <label for="name">Nomi</label>
                                            <input type="text" name="name" class="form-control js_name" id="name" value="{{ $partner->name }}" />
                                            <div class="invalid-feedback">Nomini kiriting!</div>
                                        </div>
                                    </div>
                                </div>

                                <div class="row">
                                    <div class="col-md-3 mt-1">
                                        <div class="input-field">
                                            <div class="partner-image" style="padding-top: .5rem;"></div>
                                            <div class="js_partner_image_invalid text-danger d-none">Rasmni yuklang!</div>
                                        </div>
                                    </div>
                                    <div class="col-md-6">
                                        <div class="row">
                                            <div class="col-md-6">
                                                <div class="form-group">
                                                    <label for="prefix">Telefon raqami</label>
                                                    <input type="text" name="phone" class="form-control js_phone" id="prefix" value="{{ $partner->phone }}" />
                                                    <div class="invalid-feedback">Telefon raqamini kiriting!</div>
                                                </div>
                                            </div>
                                            <div class="col-md-3">
                                                <div class="form-group">
                                                    <label>Ochilish vaqti</label>
                                                    <input type="time" name="open_time" class="form-control js_open_time" value="{{ $partner->open_time }}" />
                                                    <div class="invalid-feedback">Ochilish vaqtini kiriting!</div>
                                                </div>
                                            </div>
                                            <div class="col-md-3">
                                                <div class="form-group">
                                                    <label>Yopilish vaqti</label>
                                                    <input type="time" name="close_time" class="form-control js_close_time" value="{{ $partner->close_time }}" />
                                                    <div class="invalid-feedback">Yopilish vaqtini kiriting!</div>
                                                </div>
                                            </div>
                                            <div class="col-md-3">
                                                <div class="form-group">
                                                    <label>Minimum summasi</label>
                                                    <input type="text" name="sum_min" class="form-control js_sum_min" value="{{ $partner->sum_min }}" />
                                                    <div class="invalid-feedback">Minimum summani kiriting!</div>
                                                </div>
                                            </div>
                                            <div class="col-md-3">
                                                <label>Yetkazma summasi</label>
                                                <div class="form-group">
                                                    <input type="text" name="sum_delivery" class="form-control js_sum_delivery" value="{{ $partner->sum_delivery }}" />
                                                    <div class="invalid-feedback">Yetkazma summasini kiriting!</div>
                                                </div>
                                            </div>
                                            <div class="col-md-3">
                                                <label>Holati</label>
                                                <select class="form-control js_active" name="active">
                                                    <option @if($partner->active == 1) selected @endif value="1">Active</option>
                                                    <option @if($partner->active == 0) selected @endif value="0">No active</option>
                                                </select>
                                            </div>
                                            <div class="col-md-3">
                                                <label>Ochiq/Yopiq</label>
                                                <select class="form-control js_closed" name="closed">
                                                    <option @if($partner->closed == 0) selected @endif value="0">Ochiq</option>
                                                    <option @if($partner->closed == 1) selected @endif value="1">Yopiq</option>
                                                </select>
                                            </div>
                                            <div class="col-md-6">
                                                <label>Login</label>
                                                <div class="form-group">
                                                    <input type="text" name="login" class="form-control js_login" value="{{ $partner->login }}" />
                                                    <div class="invalid-feedback">Loginni kiriting!</div>
                                                </div>
                                            </div>
                                            <div class="col-md-6">
                                                <label>Parol</label>
                                                <div class="form-group">
                                                    <input type="text" name="password" class="form-control js_password" />
                                                    <div class="invalid-feedback">Parolni kiriting!</div>
                                                </div>
                                            </div>
                                            <div class="col-md-12">
                                                <div class="form-group">
                                                    <label for="comments">Izoh uchun</label>
                                                    <textarea class="form-control" id="comments" rows="1" name="comments">{{ $partner->comments }}</textarea>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                    <div class="col-md-3 mt-1">
                                        <div class="input-field">
                                            <div class="partner-background-image" style="margin-top: .5rem;"></div>
                                            <div class="js_background_image_invalid text-danger d-none">Orqa fon uchun rasmni yuklang!</div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <div class="modal-footer">
                            <input type="submit" class="btn btn-outline-success" value="Saqlash" name="save" />
                        </div>
                    </form>
                </div>
            </div>
        </div>

    {{-- Add category modall --}}
    @include('product.sub_category_add_modal')

@endsection


@section('script')
    <script type="text/javascript">

        $(document).ready(function() {

            $('.partner-image').imageUploader({
                preloaded: [{id: 2, src: "{{ asset($partner->image) }}"}],
            });


            // file background
            $('.partner-background-image').imageUploader({
                preloaded: [{id: 3, src: "{{ asset($partner->background) }}"}],
                imagesInputName: 'background_image',
                label: 'Orqa fon uchun rasmni yuklang'
            });



            // update partner
            $(document).on('submit', '.js_partner_add_form', function (e) {
                e.preventDefault()

                let form = $(this)
                let url = form.attr('action');
                let method = form.attr('method');
                let formData = new FormData(this);

                $.ajax({
                    type: method,
                    url: url,
                    data: formData,
                    contentType: false,
                    processData: false,
                    success: (response) => {

                        console.log(response)
                        if(!response.status) {
                            if(typeof response.errors !== 'undefined') {

                                if (response.errors.images)
                                    $('.js_partner_image_invalid').removeClass('d-none')

                                if (response.errors.login) {
                                    form.find('.js_login').addClass('is-invalid')
                                    if(response.errors.login == "The login has already been taken.")
                                        $(".js_login").siblings('.invalid-feedback').html('Bunday login mavjud.')
                                    else
                                        $(".js_login").siblings('.invalid-feedback').html('Loginni kiriting!')
                                }

                                if (response.errors.password) {
                                    form.find('.js_password').addClass('is-invalid')
                                    if(response.errors.password == "The password must be at least 3 characters.")
                                        $(".js_password").siblings('.invalid-feedback').html("Parol kamida 3 xonali bo'lishi kerak.")
                                    else
                                        $(".js_login").siblings('.invalid-feedback').html('Loginni kiriting!')
                                }

                                if (response.errors.name)
                                    form.find('.js_name').addClass('is-invalid')

                                if (response.errors.phone)
                                    form.find('.js_phone').addClass('is-invalid')

                                if (response.errors.open_time)
                                    form.find('.js_open_time').addClass('is-invalid')

                                if (response.errors.close_time)
                                    form.find('.js_close_time').addClass('is-invalid')

                                if (response.errors.sum_min)
                                    form.find('.js_sum_min').addClass('is-invalid')

                                if (response.errors.sum_delivery)
                                    form.find('.js_sum_delivery').addClass('is-invalid')

                                if (response.errors.background_image)
                                    $('.js_background_image_invalid').removeClass('d-none')
                            }
                        }

                        if (response.status) {
                            location.href = window.location.protocol + "//" + window.location.host + "/partner";
                        }
                    },
                    error: (response) => {
                        console.log(response);
                    }
                });

            });

        })

    </script>

@endsection
