<div class="modal fade text-left" id="user_add_edit_modal" tabindex="-1" role="dialog" data-backdrop="static">
    <div class="modal-dialog modal-dialog-centered modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header">
                <h4 class="modal-title" id="myModalLabel33">Foydalanuvchi qo'shish</h4>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
                </button>
            </div>
            <form action="" method="POST" class="js_user_add_from">
                @csrf
                <div class="modal-body">
                    <div class="row">
                        <div class="col-md-5 user-information">
                            <div class="form-group">
                                <label for="name">Ism familiya</label>
                                <input type="text" name="name" class="form-control js_name" id="name" />
                                <div class="invalid-feedback">Ism familiyani kiriting!</div>
                            </div>

                            <div class="form-group">
                                <label for="prefix">Telefon</label>
                                <input type="text" name="phone" class="form-control js_phone phone-mask" id="prefix" placeholder="+998" />
                                <div class="invalid-feedback">Relefon raqamni kiriting!</div>
                            </div>

                            <div class="form-group">
                                <label for="status">Status</label>
                                <select name="status" id="status" class="form-control js_status">
                                    <option value="1">Avtive</option>
                                    <option value="0">No avtive</option>
                                </select>
                            </div>

                            <div class="form-group">
                                <label for="username">Login</label>
                                <input type="text" name="username" class="form-control js_username" id="username" />
                                <input type="hidden" name="old_username" class="js_old_username" />
                                <div class="invalid-feedback">Loginni kiriting!</div>
                            </div>

                            <div class="form-group">
                                <label for="password">Parol</label>
                                <input type="text" name="password" class="form-control js_password" id="password" />
                                <div class="invalid-feedback">Parolni kiriting!</div>
                            </div>
                        </div>
                        <div class="col-md-7">
                            <div class="user-actions">
                                <label style="margin-bottom: 5px;">Huquqlar </label>
                                <ul class="huquqlar-checkbox list-group js_huquqlar_ul">
                                    @foreach($action as $a)
                                        <li class="list-group-item">
                                            @if($a->group_id == 0)
                                                <h5 class="text-center text-info mb-0">{{ $a->name }}</h5>
                                            @else
                                                <div class="custom-control custom-control-primary custom-checkbox">
                                                    <input type="checkbox" name="action[]" value="{{ $a->id }}" class="custom-control-input js_action" id="colorCheck{{ $a->id }}">
                                                    <label class="custom-control-label" for="colorCheck{{ $a->id }}">{{ $a->name }}</label>
                                                </div>
                                            @endif
                                        </li>
                                    @endforeach
                                </ul>
                                <div class="text-danger d-none js_action_invalid">Huquqni tanlang</div>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="modal-footer">
                    <input type="submit" class="btn btn-outline-primary" name="saveBtn" value="Saqlash" />
                    <button type="button" class="btn btn-outline-secondary" data-dismiss="modal">Bekor qilish</button>
                </div>
            </form>
        </div>
    </div>
</div>
