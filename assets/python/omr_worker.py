import sys
import os
import json
import traceback
import cv2
import numpy as np

# Configurar encoding para Windows
try:
    if sys.platform == "win32":
        sys.stdin.reconfigure(encoding='utf-8')
        sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

# Suprimir logs TF para manter o STDOUT limpo para comunicação JSON
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'
import tensorflow as tf
from tensorflow.keras.models import load_model
from ultralytics import YOLO

# --- CONSTANTES ---
IA_IMG_HEIGHT = 32
IA_IMG_WIDTH = 150
PADRAO_W = 600
PADRAO_H = 800
OFFSET_YOLO_X = 20
OFFSET_YOLO_Y = 21

# --- GLOBAIS (Estado Persistente) ---
model_omr = None
model_yolo = None
labels_map = None
limites_colunas_detectados = {}
current_model_paths = {} # Para verificar se os caminhos mudaram

def carregar_modelos(paths):
    """
    Carrega os modelos apenas se ainda não estiverem na memória
    ou se os caminhos mudaram.
    """
    global model_omr, model_yolo, labels_map, current_model_paths
    
    # 1. Carregar Labels
    path_labels = paths.get("labels")
    if path_labels and (labels_map is None or path_labels != current_model_paths.get("labels")):
        if os.path.exists(path_labels):
            try:
                with open(path_labels, 'r') as f:
                    raw_labels = json.load(f)
                labels_map = {str(k): v for k, v in raw_labels.items()}
                # Log via stderr para não sujar o canal de comunicação json
                sys.stderr.write(f"[INFO] Labels carregados: {len(labels_map)} itens\n")
                current_model_paths["labels"] = path_labels
            except Exception as e:
                sys.stderr.write(f"[ERRO] Falha ao ler labels: {e}\n")
                labels_map = None
    
    if labels_map is None:
        labels_map = {"0": "A", "1": "B", "2": "C", "3": "D", "4": "E", "5": "NENHUMA"}

    # 2. Carregar Modelo OMR (Keras)
    path_omr = paths.get("omr")
    if path_omr and (model_omr is None or path_omr != current_model_paths.get("omr")):
        if os.path.exists(path_omr):
            try:
                # Limpa sessão anterior se necessário (opcional, mas bom pra memória)
                if model_omr is not None:
                    del model_omr
                    tf.keras.backend.clear_session()
                
                model_omr = load_model(path_omr)
                sys.stderr.write("[INFO] Modelo OMR Keras carregado.\n")
                current_model_paths["omr"] = path_omr
            except Exception as e:
                sys.stderr.write(f"[ERRO] Falha ao carregar modelo Keras: {e}\n")
                model_omr = None

    # 3. Carregar YOLO
    path_yolo = paths.get("yolo")
    if path_yolo and (model_yolo is None or path_yolo != current_model_paths.get("yolo")):
        if os.path.exists(path_yolo):
            sys.stderr.write(f"[INFO] Carregando YOLO de: {path_yolo}\n")
            # YOLO da ultralytics gerencia sua própria memória bem
            model_yolo = YOLO(path_yolo)
            current_model_paths["yolo"] = path_yolo

def aplicar_configuracao_inteligente(layout_config, gabarito_correto):
    total = layout_config.get('total_questoes')
    if not total and gabarito_correto:
        try:
            chaves = [int(k) for k in gabarito_correto.keys() if str(k).isdigit()]
            if chaves: total = max(chaves)
        except: pass
    if not total: total = 30
    layout_config['total_questoes'] = total

    if total == 28:
        if 'questoes_por_coluna' not in layout_config: layout_config['questoes_por_coluna'] = 14
        if 'espaco_h_bolha' not in layout_config: layout_config['espaco_h_bolha'] = 32 
        if 'espaco_v_bolha' not in layout_config: layout_config['espaco_v_bolha'] = 27
    elif total == 32:
        if 'questoes_por_coluna' not in layout_config: layout_config['questoes_por_coluna'] = 16
        if 'espaco_h_bolha' not in layout_config: layout_config['espaco_h_bolha'] = 28
        if 'espaco_v_bolha' not in layout_config: layout_config['espaco_v_bolha'] = 26
    else:
        if 'questoes_por_coluna' not in layout_config: layout_config['questoes_por_coluna'] = 15
        if 'espaco_h_bolha' not in layout_config: layout_config['espaco_h_bolha'] = 30
        if 'espaco_v_bolha' not in layout_config: layout_config['espaco_v_bolha'] = 26

    return layout_config

def atualizar_layout_com_yolo(img_clean, layout_atual, img_debug=None):
    global limites_colunas_detectados
    limites_colunas_detectados = {} 

    if model_yolo is None: return layout_atual

    try:
        results = model_yolo(img_clean, verbose=False)
        boxes_questoes = []

        for result in results:
            for box in result.boxes:
                cls_id = int(box.cls[0])
                conf = float(box.conf[0])
                if cls_id == 0 and conf > 0.30: 
                    x1, y1, x2, y2 = map(int, box.xyxy[0])
                    boxes_questoes.append((x1, y1, x2, y2))
        
        if not boxes_questoes:
            # sys.stderr.write("[WARN] YOLO: Nenhuma coluna detectada. Usando layout fixo.\n")
            return layout_atual

        boxes_questoes.sort(key=lambda b: b[0])
        soma_alturas = 0
        qtd_colunas_detectadas = 0

        if len(boxes_questoes) >= 1:
            x1, y1, x2, y2 = boxes_questoes[0]
            layout_atual['coluna_1_origem_xy'] = [int(x1 + OFFSET_YOLO_X), int(y1 + OFFSET_YOLO_Y)]
            soma_alturas += (y2 - y1)
            qtd_colunas_detectadas += 1
            limites_colunas_detectados[0] = (x1, y1, x2, y2) 
        
        if len(boxes_questoes) >= 2:
            x1, y1, x2, y2 = boxes_questoes[-1]
            layout_atual['coluna_2_origem_xy'] = [int(x1 + OFFSET_YOLO_X), int(y1 + OFFSET_YOLO_Y)]
            soma_alturas += (y2 - y1)
            qtd_colunas_detectadas += 1
            limites_colunas_detectados[1] = (x1, y1, x2, y2)

        if qtd_colunas_detectadas > 0:
            altura_media = soma_alturas / qtd_colunas_detectadas
            q_por_col = layout_atual.get('questoes_por_coluna', 15)
            if q_por_col > 0:
                novo_espaco_v = (altura_media / q_por_col) * 0.98
                layout_atual['espaco_v_bolha'] = novo_espaco_v

        return layout_atual

    except Exception as e:
        sys.stderr.write(f"[ERRO] Falha no YOLO: {e}\n")
        return layout_atual

def _get_crop_para_questao(thresh_img, num_questao_atual, layout):
    q_por_col = layout.get('questoes_por_coluna', 15)
    raio = layout.get('raio_bolha', 6)
    col1 = layout.get('coluna_1_origem_xy') or [0,0]
    col2 = layout.get('coluna_2_origem_xy') or [0,0]
    origens = [col1, col2]
    
    espaco_h = layout.get('espaco_h_bolha', 28)
    espaco_v = layout.get('espaco_v_bolha', 26)

    padding_v = int(raio * 1.4) 
    padding_h = int(raio * 1.4)
    
    if num_questao_atual <= q_por_col:
        col_idx = 0
        q_idx = num_questao_atual - 1
    else:
        col_idx = 1
        q_idx = num_questao_atual - q_por_col - 1
    
    if col_idx >= len(origens): return None, None

    origem_x, origem_y = origens[col_idx]
    if origem_x == 0 and origem_y == 0: return None, None

    y_centro = int(origem_y + (q_idx * espaco_v))
    x_A = int(origem_x)
    x_E = int(origem_x + (4 * espaco_h))
    
    y1 = y_centro - padding_v
    y2 = y_centro + padding_v
    x1 = x_A - padding_h
    x2 = x_E + padding_h
    
    limites = limites_colunas_detectados.get(col_idx)
    if limites:
        bx1, by1, bx2, by2 = limites
        y1 = max(y1, by1)
        y2 = min(y2, by2)
        x1 = max(x1, bx1) 
        x2 = min(x2, bx2)

    h_img, w_img = thresh_img.shape
    y1 = max(0, y1); y2 = min(h_img, y2)
    x1 = max(0, x1); x2 = min(w_img, x2)
    
    if y2 <= y1 or x2 <= x1: return None, None

    return thresh_img[y1:y2, x1:x2], (x1, y1, x2, y2, y_centro)

def ler_por_pixel_count(crop_thresh, num_opcoes=5):
    h, w = crop_thresh.shape
    step = w // num_opcoes
    pixels = []
    for i in range(num_opcoes):
        x_start = i * step
        x_end = (i + 1) * step
        roi = crop_thresh[:, x_start:x_end]
        total = cv2.countNonZero(roi)
        pixels.append(total)
    
    LIMIT = 50 
    max_pixels = max(pixels)
    if max_pixels > LIMIT:
        idx_max = np.argmax(pixels)
        return str(idx_max)
    return "5"

def processar_prova(imagem_path, layout_config, gabarito_correto, model_paths):
    # Carregamento inteligente (só carrega se necessário)
    carregar_modelos(model_paths)
    
    if not os.path.exists(imagem_path):
         return {"sucesso": False, "erro": f"Arquivo não encontrado: {imagem_path}"}

    img_array = np.fromfile(imagem_path, np.uint8)
    img_orig = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
    if img_orig is None: return {"sucesso": False, "erro": "Falha ao ler imagem (formato inválido ou corrompido)"}

    planificada = cv2.resize(img_orig, (PADRAO_W, PADRAO_H), interpolation=cv2.INTER_AREA)
    img_out = planificada.copy() 

    layout_config = aplicar_configuracao_inteligente(layout_config, gabarito_correto)
    layout_config = atualizar_layout_com_yolo(planificada, layout_config, img_debug=None)

    gray = cv2.cvtColor(planificada, cv2.COLOR_BGR2GRAY)
    thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV | cv2.THRESH_OTSU)[1]

    batch_imgs = []
    mapa_indices = []
    respostas_detectadas = {}
    
    total_questoes = layout_config.get('total_questoes', 30)

    for q_num in range(1, total_questoes + 1):
        crop, coords = _get_crop_para_questao(thresh, q_num, layout_config)

        if crop is not None and crop.size > 0 and crop.shape[0] > 5 and crop.shape[1] > 5:
            try:
                crop_resized = cv2.resize(crop, (IA_IMG_WIDTH, IA_IMG_HEIGHT))
                crop_norm = crop_resized.astype("float32") / 255.0
                crop_expanded = np.expand_dims(crop_norm, axis=-1)
                batch_imgs.append(crop_expanded)
                mapa_indices.append(q_num)
            except Exception:
                respostas_detectadas[str(q_num)] = "ERRO"
        else:
            respostas_detectadas[str(q_num)] = "VAZIO"

    acertos = 0
    usou_ia = False

    if batch_imgs and model_omr:
        try:
            batch_array = np.array(batch_imgs)
            predictions = model_omr.predict(batch_array, verbose=0)
            usou_ia = True
            for i, pred_vector in enumerate(predictions):
                q_num = mapa_indices[i]
                idx_max = np.argmax(pred_vector)
                letra = labels_map.get(str(idx_max), "UNK")
                if letra == "NENHUMA": letra = "VAZIO"
                respostas_detectadas[str(q_num)] = letra
        except Exception as e:
            sys.stderr.write(f"[ERRO IA] {e}. Fallback Pixel Count.\n")
            # Se IA falhar no meio do processo, fallback para pixel count nesse lote
            usou_ia = False 

    # Fallback se não usou IA ou se falhou
    if not usou_ia:
        # Re-processar as questões que estavam no batch via pixel count
         for i, q_num in enumerate(mapa_indices):
            # Recorta novamente pois não guardamos o crop original, apenas o processado
            crop, _ = _get_crop_para_questao(thresh, q_num, layout_config)
            if crop is not None:
                idx_pixel = ler_por_pixel_count(crop)
                letra = labels_map.get(idx_pixel, "VAZIO")
                if letra == "NENHUMA": letra = "VAZIO"
                respostas_detectadas[str(q_num)] = letra

    # --- DESENHO DO FEEDBACK ---
    letras = ["A", "B", "C", "D", "E"]
    
    for q_num_str, letra_aluno in respostas_detectadas.items():
        q_num = int(q_num_str)
        
        q_por_col = layout_config.get('questoes_por_coluna', 15)
        espaco_h = layout_config.get('espaco_h_bolha', 28)
        espaco_v = layout_config.get('espaco_v_bolha', 26)
        col_idx = 0 if q_num <= q_por_col else 1
        q_idx = (q_num - 1) if col_idx == 0 else (q_num - q_por_col - 1)
        origens = [layout_config.get('coluna_1_origem_xy'), layout_config.get('coluna_2_origem_xy')]
        
        if origens[col_idx]:
            ox, oy = origens[col_idx]
            y_pos = int(oy + (q_idx * espaco_v))
            
            letra_gabarito = gabarito_correto.get(str(q_num)) if gabarito_correto else None
            
            if letra_aluno in letras:
                l_idx = letras.index(letra_aluno)
                x_pos = int(ox + (l_idx * espaco_h))
                
                if letra_gabarito:
                    if letra_aluno == letra_gabarito:
                        cv2.circle(img_out, (x_pos, y_pos), 10, (0, 255, 0), 2)
                        acertos += 1
                    else:
                        cv2.circle(img_out, (x_pos, y_pos), 10, (0, 0, 255), 2)
                else:
                    cv2.circle(img_out, (x_pos, y_pos), 10, (0, 0, 255), 2)

            if letra_gabarito and letra_gabarito in letras:
                if letra_aluno != letra_gabarito:
                    l_idx_gab = letras.index(letra_gabarito)
                    x_pos_gab = int(ox + (l_idx_gab * espaco_h))
                    cv2.circle(img_out, (x_pos_gab, y_pos), 10, (120, 120, 120), 2)

    out_path = os.path.join(os.path.dirname(imagem_path), f"checked_{os.path.basename(imagem_path)}")
    cv2.imwrite(out_path, img_out)

    return {
        "sucesso": True,
        "caminho_imagem_corrigida": out_path,
        "respostas_detectadas": respostas_detectadas,
        "acertos": acertos,
        "total_questoes": total_questoes
    }

def main():
    # Aviso inicial para o Flutter saber que o processo subiu e as bibliotecas foram importadas
    # Nota: Os modelos ainda não estão carregados, pois dependem dos caminhos enviados no JSON.
    # O carregamento real ocorrerá na primeira requisição.
    print("READY")
    sys.stdout.flush()

    while True:
        try:
            # Lê uma linha do stdin (aguarda até chegar)
            line = sys.stdin.readline()
            
            # Se receber string vazia, significa EOF (Flutter fechou o pipe), então encerra.
            if not line:
                break
            
            # Limpa espaços em branco extras
            line = line.strip()
            if not line:
                continue

            try:
                dados = json.loads(line)
                
                # Executa o processamento
                res = processar_prova(
                    dados["caminho_imagem"], 
                    dados["layout_config"], 
                    dados["gabarito"], 
                    dados.get("model_paths", {})
                )
                
                # Retorna resultado em JSON (uma linha)
                print(json.dumps(res))
                sys.stdout.flush()

            except json.JSONDecodeError:
                err = json.dumps({"sucesso": False, "erro": "JSON inválido recebido no Python"})
                print(err)
                sys.stdout.flush()
            except Exception as e:
                # Captura erros de lógica interna para não derrubar o worker
                err = json.dumps({
                    "sucesso": False, 
                    "erro": str(e), 
                    "trace": traceback.format_exc()
                })
                print(err)
                sys.stdout.flush()

        except KeyboardInterrupt:
            break
        except Exception as e:
            # Erro catastrófico de I/O
            sys.stderr.write(f"Critical Worker Error: {e}\n")
            break

if __name__ == "__main__":
    main()