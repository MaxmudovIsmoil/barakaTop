@extends('layouts.app')


@section('content')

    <div class="content-wrapper">
            <div class="content-body">
                <a href="{{ route('product.index') }}" class="position-absolute btn_back zindex-1 p-0" title="Orqaga qaytish">
                    <i class="fas fa-long-arrow-alt-left"></i>
                </a>
                <h3 class="text-center text-info position-absolute zindex-1" style="left: 42%; top: 2%">Maxsulot qo'shish</h3>
                <div class="card pt-5">
                    <form action="{{ route('product.store') }}" method="POST" class="js_product_add_form" enctype="multipart/form-data">
                        @csrf
                        <div class="modal-body">
                            <div class="needs-validation">
                                <div class="row">
                                    <div class="col-md-3">
                                        <label>Kategoriyani tanlang</label>
                                        <select class="form-control js_partner_id select2" id="partner_id" name="partner_id">
                                            <option value="0">---</option>
                                            @foreach($partners as $p)
                                                <option value="{{ $p->id }}">{{ $p->name }}</option>
                                            @endforeach
                                        </select>
                                    </div>
                                    <div class="col-md-3">
                                        <label>Ichki kategoriyani tanlang</label>
                                        <select class="form-control js_sub_category js_parent_id select2" name="parent_id">
                                            <option value="0">---</option>
                                            @foreach($parents as $p)
                                                <option value="{{ $p->id }}">{{ $p->name }}</option>
                                            @endforeach
                                        </select>
                                    </div>
                                    <div class="com-md-1 pr-4 pl-3">
                                        <a href="javascript:void(0);" class="js_btn_plus" title="Kategoriya qo'shish">
                                            <i class="fas fa-plus" style="font-size: 32px; margin-top: 25px;"></i>
                                        </a>
                                    </div>
                                    <div class="col-md-5">
                                        <label>Nomi</label>
                                        <div class="form-group">
                                            <input type="text" name="name" class="form-control js_name" />
                                            <div class="invalid-feedback">Nomini kiriting!</div>
                                        </div>
                                    </div>
                                </div>

                                <div class="row">
                                    <div class="col-md-3 mt-1">
                                        <div class="input-field">
                                            <div class="product-image" style="padding-top: .5rem;"></div>
                                            <div class="js_product_image_invalid text-danger d-none">Rasmni yuklang!</div>
                                        </div>
                                    </div>
                                    <div class="col-md-9">
                                        <div class="row">
                                            <div class="col-md-4">
                                                <label>Narxi</label>
                                                <div class="form-group">
                                                    <input type="text" name="price" class="form-control js_price" />
                                                    <div class="invalid-feedback">Narxini kiriting!</div>
                                                </div>
                                            </div>
                                            <div class="col-md-4">
                                                <label>Chegirma</label>
                                                <div class="form-group">
                                                    <input type="text" name="discount" class="form-control js_discount" value="0" />
                                                    <div class="invalid-feedback">Nomini kiriting!</div>
                                                </div>
                                            </div>
                                            <div class="col-md-4">
                                                <label>Holati</label>
                                                <select class="form-control js_active" name="active">
                                                    <option value="1">Active</option>
                                                    <option value="0">No active</option>
                                                </select>
                                            </div>
                                            <div class="col-md-12">
                                                <div class="form-group">
                                                    <label for="comments">Izoh uchun</label>
                                                    <textarea class="form-control" id="comments" rows="4" name="comments"></textarea>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <div class="modal-footer">
                            <i class="fas fa-check check-success-icon js_check_icon d-none mr-4"></i>
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
    <script src="{{ asset('js/function_product.js') }}"></script>

    <script type="text/javascript">
        $(document).ready(function() {

            // file uploaded
            $('.product-image').imageUploader();

        });
    </script>

@endsection
